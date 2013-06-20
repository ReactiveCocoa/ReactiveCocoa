//
//  NSObject+RACObservablePropertyObserving.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/06/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACObservablePropertyObserving.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"

static RACDisposable *addObserverToTargetForKeyPathWillChangeBlockDidChangeBlock(NSObject *observer, NSObject *target, NSString *keyPath, void(^willChangeBlock)(BOOL), void(^didChangeBlock)(BOOL, BOOL, id)) {
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	BOOL keyPathHasOneComponent = (keyPathComponents.count == 1);
	NSString *firstKeyPathComponent = keyPathComponents[0];
	NSString *keyPathByDeletingFirstKeyPathComponent = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	// The disposable that groups all disposal necessary to clean up the callbacks
	// added to the value of the first key path component.
	__block RACCompoundDisposable *firstComponentDisposable = [RACCompoundDisposable compoundDisposable];
	[disposable addDisposable:firstComponentDisposable];

	// Adds didChangeBlock as a callback on the value's deallocation. Also adds
	// the logic to clean up the callback to firstComponentDisposable.
	void (^addDeallocObserverToValue)(NSObject *) = ^(NSObject *value) {
		if (didChangeBlock == nil) return;
		RACCompoundDisposable *valueDisposable = value.rac_deallocDisposable;
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			didChangeBlock(keyPathHasOneComponent, YES, nil);
		}];
		[valueDisposable addDisposable:deallocDisposable];
		@synchronized (disposable) {
			[firstComponentDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[valueDisposable removeDisposable:deallocDisposable];
			}]];
		}
	};

	// Adds willChangeBlock and didChangeBlock as callbacks for changes to the
	// remaining path components on the value. Also adds the logic to clean up the
	// callbacks to firstComponentDisposable.
	void (^addObserverToValue)(NSObject *) = ^(NSObject *value) {
		RACDisposable *observerDisposable = [value rac_addObserver:observer forKeyPath:keyPathByDeletingFirstKeyPathComponent willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock];
		@synchronized (disposable) {
			[firstComponentDisposable addDisposable:observerDisposable];
		}
	};

	// Observe only the first key path component, when the value changes clean up
	// the callbacks on the old value, add callbacks to the new value and call
	// willChangeBlock and didChangeBlock as needed.
	//
	// Note this does not use NSKeyValueObservingOptionInitial so this only
	// handles changes to the value, callbacks to the initial value must be added
	// separately.
	RACKVOTrampoline *trampoline = [target rac_addObserver:observer forKeyPath:firstKeyPathComponent options:NSKeyValueObservingOptionPrior block:^(id trampolineTarget, id trampolineObserver, NSDictionary *change) {
		// If this is a prior notification, clean up all the callbacks added to the
		// previous value and call willChangeBlock. Everything else is deferred
		// until after we get the notification after the change.
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			@synchronized (disposable) {
				[firstComponentDisposable dispose];
				[disposable removeDisposable:firstComponentDisposable];
			}
			if (willChangeBlock != nil) {
				willChangeBlock(keyPathHasOneComponent);
			}
			return;
		}

		// From here the notification is not prior.
		NSObject *value = [trampolineTarget valueForKey:firstKeyPathComponent];

		// If the value has changed but is nil, there is no need to add callbacks to
		// it, just call didChangeBlock.
		if (value == nil) {
			if (didChangeBlock != nil) {
				didChangeBlock(keyPathHasOneComponent, NO, nil);
			}
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
		// other callbacks, just call didChangeBlock with the value itself.
		if (keyPathHasOneComponent) {
			if (didChangeBlock != nil) {
				didChangeBlock(YES, NO, value);
			}
			return;
		}

		// The value has changed, is not nil, and there are more key path components
		// to consider. Add the callbacks to the value for the remaining key path
		// components and call didChangeBlock with the current value of the full
		// key path.
		addObserverToValue(value);
		if (didChangeBlock != nil) {
			didChangeBlock(NO, NO, [value valueForKeyPath:keyPathByDeletingFirstKeyPathComponent]);
		}
	}];

	// Stop the KVO observation when this one is disposed of.
	[disposable addDisposable:trampoline];

	// Add the callbacks to the initial value if needed.
	if (!keyPathHasOneComponent) {
		NSObject *value = [target valueForKey:firstKeyPathComponent];
		if (value != nil) {
			addDeallocObserverToValue(value);
			addObserverToValue(value);
		}
	}

	// Dispose of this observation if the target or the observer deallocate.
	[observer.rac_deallocDisposable addDisposable:disposable];
	[target.rac_deallocDisposable addDisposable:disposable];
	
	return disposable;
}

@implementation NSObject (RACObservablePropertyObserving)

- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void (^)(BOOL))willChangeBlock didChangeBlock:(void (^)(BOOL, BOOL, id))didChangeBlock {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);

	NSRecursiveLock *serializationLock = [[NSRecursiveLock alloc] init];
	serializationLock.name = @"RACObservablePropertyObservingSerializationLock";

	void (^serializingWillChangeBlock)(BOOL) = nil;
	if (willChangeBlock != nil) {
		serializingWillChangeBlock = ^ (BOOL triggeredByLastKeyPathComponent) {
			[serializationLock lock];
			@onExit {
				[serializationLock unlock];
			};
			willChangeBlock(triggeredByLastKeyPathComponent);
		};
	}

	void (^serializingDidChangeBlock)(BOOL, BOOL, id) = nil;
	if (didChangeBlock != nil) {
		serializingDidChangeBlock = ^ (BOOL triggeredByLastKeyPathComponent, BOOL triggeredByDeallocation, id value) {
			[serializationLock lock];
			@onExit {
				[serializationLock unlock];
			};
			didChangeBlock(triggeredByLastKeyPathComponent, triggeredByDeallocation, value);
		};
	}

	return addObserverToTargetForKeyPathWillChangeBlockDidChangeBlock(observer, self, keyPath, willChangeBlock, didChangeBlock);
}

@end
