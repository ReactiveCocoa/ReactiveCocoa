//
//  NSObject+RACPropertySubscribing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EXTKeyPathCoding.h"
#import "metamacros.h"
#import "RACDeprecated.h"

/// Creates a signal which observes `KEYPATH` on `TARGET` for changes.
///
/// The observation continues until `TARGET` is deallocated. If any intermediate
/// object is deallocated instead, it will be assumed to have been set to nil.
///
/// Examples
///
///    // Observes self, and doesn't stop until self is deallocated.
///    RACSignal *selfSignal = RACObserve(self, arrayController.items);
///
///    // Observes the array controller, and stops when the array controller is
///    // deallocated.
///    RACSignal *arrayControllerSignal = RACObserve(self.arrayController, items);
///
///    // Observes obj.arrayController, and stops when the array controller is
///    // deallocated.
///    RACSignal *signal2 = RACObserve(obj.arrayController, items);
///
/// Returns a signal which sends the current value of the key path on
/// subscription, then sends the new value every time it changes, and sends
/// completed when `TARGET` is deallocated.
#ifndef WE_PROMISE_TO_MIGRATE_TO_REACTIVECOCOA_3_0
	#define RACObserve(TARGET, KEYPATH) \
		RACObserve_(TARGET, KEYPATH)
#else
	#define RACObserve(TARGET, KEYPATH) \
		/* If `TARGET` does not start with `self`, warn about the new memory
		 * management behavior */ \
		metamacro_if_eq(1, metamacro_argcount(RACObserve_warn_ ## TARGET 1)) \
			( \
				_Pragma("message \"RACObserve no longer stops when self deallocates\"") \
				RACObserve_(TARGET, KEYPATH) \
			) \
			(RACObserve_(TARGET, KEYPATH))
#endif

@class RACDisposable;
@class RACSignal;

@interface NSObject (RACPropertySubscribing)

/// Creates a signal to observe the value at the given key path.
///
/// The initial value is sent on subscription, the subsequent values are sent
/// from whichever thread the change occured on, even if it doesn't have a valid
/// scheduler.
///
/// Returns a signal that immediately sends the receiver's current value at the
/// given keypath, then any changes thereafter.
- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath;

/// Creates a signal to observe the changes of the given key path.
///
/// The initial value is sent on subscription, the subsequent values are sent
/// from whichever thread the change occured on, even if it doesn't have a valid
/// scheduler.
///
/// Returns a signal that sends tuples containing the current value at the key
/// path and the change dictionary for each KVO callback.
- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options;

@end

/// Do not use this directly. Use the RACObserve macro above.
#define RACObserve_(TARGET, KEYPATH) \
    [(id)(TARGET) rac_valuesForKeyPath:@keypath(TARGET, KEYPATH)]

#define RACObserve_warn_self \
	2,

@interface NSObject (RACDeprecatedPropertySubscribing)

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath observer:(NSObject *)observer RACDeprecated("Use -rac_valuesForKeyPath: instead");
- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer RACDeprecated("Use -rac_valuesAndChangesForKeyPath:options:observer: instead");

@end

@interface NSObject (RACUnavailablePropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
+ (RACSignal *)rac_signalWithStartingValueFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesAndChangesForKeyPath:options:observer: instead.")));
- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
- (RACSignal *)rac_signalWithStartingValueForKeyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal __attribute__((unavailable("Use -[RACSignal setKeyPath:onObject:] instead")));

@end
