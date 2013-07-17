//
//  NSObject+RACKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"

NSString * const RACKeyValueChangeCausedByDeallocationKey = @"RACKeyValueChangeCausedByDeallocationKey";
NSString * const RACKeyValueChangeAffectedOnlyLastComponentKey = @"RACKeyValueChangeAffectedOnlyLastComponentKey";

@implementation NSObject (RACKVOWrapper)

- (RACDisposable *)rac_observeKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer block:(void (^)(id, NSDictionary *))block {
	NSCParameterAssert(block != nil);
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	@unsafeify(observer);
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	BOOL keyPathHasOneComponent = (keyPathComponents.count == 1);
	NSString *keyPathHead = keyPathComponents[0];
	NSString *keyPathTail = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	// The disposable that groups all disposal necessary to clean up the callbacks
	// added to the value of the first key path component.
	__block RACCompoundDisposable *firstComponentDisposable = [RACCompoundDisposable compoundDisposable];
	[disposable addDisposable:firstComponentDisposable];

	// Adds the callback block to the value's deallocation. Also adds the logic to
	// clean up the callback to firstComponentDisposable.
	void (^addDeallocObserverToValue)(NSObject *) = ^(NSObject *value) {
		NSDictionary *change = @{
			NSKeyValueChangeKindKey: @(NSKeyValueChangeSetting),
			NSKeyValueChangeNewKey: NSNull.null,
			RACKeyValueChangeCausedByDeallocationKey: @YES,
			RACKeyValueChangeAffectedOnlyLastComponentKey: @(keyPathHasOneComponent)
		};

		// If a key path value is the observer, commonly when a key path begins
		// with "self", we prevent deallocation triggered callbacks for any such key
		// path components. Thus, the observer's deallocation is not considered a
		// change to the key path.
		@strongify(observer);
		if (value == observer) return;

		RACCompoundDisposable *valueDisposable = value.rac_deallocDisposable;
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			block(nil, change);
		}];
		[valueDisposable addDisposable:deallocDisposable];
		@synchronized (disposable) {
			[firstComponentDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[valueDisposable removeDisposable:deallocDisposable];
			}]];
		}
	};

	// Adds the callback block to the remaining path components on the value. Also
	// adds the logic to clean up the callbacks to firstComponentDisposable.
	void (^addObserverToValue)(NSObject *) = ^(NSObject *value) {
		@strongify(observer);
		RACDisposable *observerDisposable = [value rac_observeKeyPath:keyPathTail options:(options & ~NSKeyValueObservingOptionInitial) observer:observer block:block];
		@synchronized (disposable) {
			[firstComponentDisposable addDisposable:observerDisposable];
		}
	};

	// Observe only the first key path component, when the value changes clean up
	// the callbacks on the old value, add callbacks to the new value and call the
	// callback block as needed.
	//
	// Note this does not use NSKeyValueObservingOptionInitial so this only
	// handles changes to the value, callbacks to the initial value must be added
	// separately.
	NSKeyValueObservingOptions trampolineOptions = (options | NSKeyValueObservingOptionPrior) & ~NSKeyValueObservingOptionInitial;
	RACKVOTrampoline *trampoline = [[RACKVOTrampoline alloc] initWithTarget:self observer:observer keyPath:keyPathHead options:trampolineOptions block:^(id trampolineTarget, id trampolineObserver, NSDictionary *change) {
		// Prepare the change dictionary by adding the RAC specific keys
		{
			NSMutableDictionary *newChange = [change mutableCopy];
			newChange[RACKeyValueChangeCausedByDeallocationKey] = @NO;
			newChange[RACKeyValueChangeAffectedOnlyLastComponentKey] = @(keyPathHasOneComponent);
			change = newChange.copy;
		}

		// If this is a prior notification, clean up all the callbacks added to the
		// previous value and call the callback block. Everything else is deferred
		// until after we get the notification after the change.
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			@synchronized (disposable) {
				[firstComponentDisposable dispose];
			}
			if ((options & NSKeyValueObservingOptionPrior) != 0) {
				block([trampolineTarget valueForKeyPath:keyPath], change);
			}
			return;
		}

		// From here the notification is not prior.
		NSObject *value = [trampolineTarget valueForKey:keyPathHead];

		// If the value has changed but is nil, there is no need to add callbacks to
		// it, just call the callback block.
		if (value == nil) {
			block(nil, change);
			return;
		}

		// From here the notification is not prior and the value is not nil.

		// Create a new firstComponentDisposable while getting rid of the old one at
		// the same time, in case this is being called concurrently.
		@synchronized (disposable) {
			[firstComponentDisposable dispose];
			[disposable removeDisposable:firstComponentDisposable];
			firstComponentDisposable = [RACCompoundDisposable compoundDisposable];
			[disposable addDisposable:firstComponentDisposable];
		}
		addDeallocObserverToValue(value);

		// If there are no further key path components, there is no need to add the
		// other callbacks, just call the callback block with the value itself.
		if (keyPathHasOneComponent) {
			block(value, change);
			return;
		}

		// The value has changed, is not nil, and there are more key path components
		// to consider. Add the callbacks to the value for the remaining key path
		// components and call the callback block with the current value of the full
		// key path.
		addObserverToValue(value);
		block([value valueForKeyPath:keyPathTail], change);
	}];

	// Stop the KVO observation when this one is disposed of.
	[disposable addDisposable:trampoline];

	// Add the callbacks to the initial value if needed.
	NSObject *value = [self valueForKey:keyPathHead];
	if (value != nil) {
		addDeallocObserverToValue(value);
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
			RACKeyValueChangeCausedByDeallocationKey: @NO,
			RACKeyValueChangeAffectedOnlyLastComponentKey: @NO
		};
		block(initialValue, initialChange);
	}


	RACCompoundDisposable *observerDisposable = observer.rac_deallocDisposable;
	RACCompoundDisposable *selfDisposable = self.rac_deallocDisposable;
	// Dispose of this observation if the receiver or the observer deallocate.
	[observerDisposable addDisposable:disposable];
	[selfDisposable addDisposable:disposable];

	return disposable;
}

@end

@implementation NSObject (RACKVOWrapperDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	return [[RACKVOTrampoline alloc] initWithTarget:self observer:observer keyPath:keyPath options:options block:block];
}

#pragma clang diagnostic pop

@end
