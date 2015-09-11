//
//  NSObject+RACKVOWrapper.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "EXTRuntimeExtensions.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"
#import "RACSerialDisposable.h"

@implementation NSObject (RACKVOWrapper)

- (RACDisposable *)rac_observeKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(__weak NSObject *)weakObserver block:(void (^)(id, NSDictionary *, BOOL, BOOL))block {
	NSCParameterAssert(block != nil);
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);

	keyPath = [keyPath copy];

	NSObject *strongObserver = weakObserver;

	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	BOOL keyPathHasOneComponent = (keyPathComponents.count == 1);
	NSString *keyPathHead = keyPathComponents[0];
	NSString *keyPathTail = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	// The disposable that groups all disposal necessary to clean up the callbacks
	// added to the value of the first key path component.
	RACSerialDisposable *firstComponentSerialDisposable = [RACSerialDisposable serialDisposableWithDisposable:[RACCompoundDisposable compoundDisposable]];
	RACCompoundDisposable * (^firstComponentDisposable)(void) = ^{
		return (RACCompoundDisposable *)firstComponentSerialDisposable.disposable;
	};

	[disposable addDisposable:firstComponentSerialDisposable];

	BOOL shouldAddDeallocObserver = NO;

	objc_property_t property = class_getProperty(object_getClass(self), keyPathHead.UTF8String);
	if (property != NULL) {
		rac_propertyAttributes *attributes = rac_copyPropertyAttributes(property);
		if (attributes != NULL) {
			@onExit {
				free(attributes);
			};

			BOOL isObject = attributes->objectClass != nil || strstr(attributes->type, @encode(id)) == attributes->type;
			BOOL isProtocol = attributes->objectClass == NSClassFromString(@"Protocol");
			BOOL isBlock = strcmp(attributes->type, @encode(void(^)())) == 0;
			BOOL isWeak = attributes->weak;

			// If this property isn't actually an object (or is a Class object),
			// no point in observing the deallocation of the wrapper returned by
			// KVC.
			//
			// If this property is an object, but not declared `weak`, we
			// don't need to watch for it spontaneously being set to nil.
			//
			// Attempting to observe non-weak properties will result in
			// broken behavior for dynamic getters, so don't even try.
			shouldAddDeallocObserver = isObject && isWeak && !isBlock && !isProtocol;
		}
	}

	// Adds the callback block to the value's deallocation. Also adds the logic to
	// clean up the callback to the firstComponentDisposable.
	void (^addDeallocObserverToPropertyValue)(NSObject *) = ^(NSObject *value) {
		if (!shouldAddDeallocObserver) return;

		// If a key path value is the observer, commonly when a key path begins
		// with "self", we prevent deallocation triggered callbacks for any such key
		// path components. Thus, the observer's deallocation is not considered a
		// change to the key path.
		if (value == weakObserver) return;

		NSDictionary *change = @{
			NSKeyValueChangeKindKey: @(NSKeyValueChangeSetting),
			NSKeyValueChangeNewKey: NSNull.null,
		};

		RACCompoundDisposable *valueDisposable = value.rac_deallocDisposable;
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			block(nil, change, YES, keyPathHasOneComponent);
		}];

		[valueDisposable addDisposable:deallocDisposable];
		[firstComponentDisposable() addDisposable:[RACDisposable disposableWithBlock:^{
			[valueDisposable removeDisposable:deallocDisposable];
		}]];
	};

	// Adds the callback block to the remaining path components on the value. Also
	// adds the logic to clean up the callbacks to the firstComponentDisposable.
	void (^addObserverToValue)(NSObject *) = ^(NSObject *value) {
		RACDisposable *observerDisposable = [value rac_observeKeyPath:keyPathTail options:(options & ~NSKeyValueObservingOptionInitial) observer:weakObserver block:block];
		[firstComponentDisposable() addDisposable:observerDisposable];
	};

	// Observe only the first key path component, when the value changes clean up
	// the callbacks on the old value, add callbacks to the new value and call the
	// callback block as needed.
	//
	// Note this does not use NSKeyValueObservingOptionInitial so this only
	// handles changes to the value, callbacks to the initial value must be added
	// separately.
	NSKeyValueObservingOptions trampolineOptions = (options | NSKeyValueObservingOptionPrior) & ~NSKeyValueObservingOptionInitial;
	RACKVOTrampoline *trampoline = [[RACKVOTrampoline alloc] initWithTarget:self observer:strongObserver keyPath:keyPathHead options:trampolineOptions block:^(id trampolineTarget, id trampolineObserver, NSDictionary *change) {
		// If this is a prior notification, clean up all the callbacks added to the
		// previous value and call the callback block. Everything else is deferred
		// until after we get the notification after the change.
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			[firstComponentDisposable() dispose];

			if ((options & NSKeyValueObservingOptionPrior) != 0) {
				block([trampolineTarget valueForKeyPath:keyPath], change, NO, keyPathHasOneComponent);
			}

			return;
		}

		// From here the notification is not prior.
		NSObject *value = [trampolineTarget valueForKey:keyPathHead];

		// If the value has changed but is nil, there is no need to add callbacks to
		// it, just call the callback block.
		if (value == nil) {
			block(nil, change, NO, keyPathHasOneComponent);
			return;
		}

		// From here the notification is not prior and the value is not nil.

		// Create a new firstComponentDisposable while getting rid of the old one at
		// the same time, in case this is being called concurrently.
		RACDisposable *oldFirstComponentDisposable = [firstComponentSerialDisposable swapInDisposable:[RACCompoundDisposable compoundDisposable]];
		[oldFirstComponentDisposable dispose];

		addDeallocObserverToPropertyValue(value);

		// If there are no further key path components, there is no need to add the
		// other callbacks, just call the callback block with the value itself.
		if (keyPathHasOneComponent) {
			block(value, change, NO, keyPathHasOneComponent);
			return;
		}

		// The value has changed, is not nil, and there are more key path components
		// to consider. Add the callbacks to the value for the remaining key path
		// components and call the callback block with the current value of the full
		// key path.
		addObserverToValue(value);
		block([value valueForKeyPath:keyPathTail], change, NO, keyPathHasOneComponent);
	}];

	// Stop the KVO observation when this one is disposed of.
	[disposable addDisposable:trampoline];

	// Add the callbacks to the initial value if needed.
	NSObject *value = [self valueForKey:keyPathHead];
	if (value != nil) {
		addDeallocObserverToPropertyValue(value);

		if (!keyPathHasOneComponent) {
			addObserverToValue(value);
		}
	}

	// Call the block with the initial value if needed.
	if ((options & NSKeyValueObservingOptionInitial) != 0) {
		id initialValue = [self valueForKeyPath:keyPath];
		NSDictionary *initialChange = @{
			NSKeyValueChangeKindKey: @(NSKeyValueChangeSetting),
			NSKeyValueChangeNewKey: initialValue ?: NSNull.null,
		};
		block(initialValue, initialChange, NO, keyPathHasOneComponent);
	}


	RACCompoundDisposable *observerDisposable = strongObserver.rac_deallocDisposable;
	RACCompoundDisposable *selfDisposable = self.rac_deallocDisposable;
	// Dispose of this observation if the receiver or the observer deallocate.
	[observerDisposable addDisposable:disposable];
	[selfDisposable addDisposable:disposable];

	return [RACDisposable disposableWithBlock:^{
		[disposable dispose];
		[observerDisposable removeDisposable:disposable];
		[selfDisposable removeDisposable:disposable];
	}];
}

@end
