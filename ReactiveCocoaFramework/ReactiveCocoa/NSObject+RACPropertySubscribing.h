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
#define RACObserve(TARGET, KEYPATH) \
    [(id)(TARGET) rac_valuesForKeyPath:@keypath(TARGET, KEYPATH)]

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
@interface NSObject (RACUnavailablePropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
+ (RACSignal *)rac_signalWithStartingValueFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesAndChangesForKeyPath:options:observer: instead.")));
- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
- (RACSignal *)rac_signalWithStartingValueForKeyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal __attribute__((unavailable("Use -[RACSignal setKeyPath:onObject:] instead")));

@end
