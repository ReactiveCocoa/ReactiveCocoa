//
//  NSObject+RACPropertySubscribing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import <ReactiveCocoa/metamacros.h>

// Creates a signal which observes the given key path for changes.
//
// If given one argument, the key path is assumed to be relative to self.
// If given two arguments, the first argument is the object to observe, and the
// second argument is the key path to observe upon it.
//
// In either case, the observation continues until the observed object _or self_
// is deallocated. No intermediate objects along the key path should be
// deallocated while the observation exists.
//
// Make sure to `@strongify(self)` when using this macro within a block! The
// macro will _always_ reference `self`, which can silently introduce a retain
// cycle within a block. As a result, you should make sure that `self` is a weak
// reference (e.g., created by `@weakify` and `@strongify`) before the
// expression that uses `RACAble` or `RACAbleWithStart`.
//
// Examples
//
//    // Observes self, and doesn't stop until self is deallocated. The array
//    // controller should not be deallocated during this time.
//    RACSignal *signal1 = RACAble(self.arrayController.items);
//
//    // Observes obj.arrayController, and stops when _self_ or the array
//    // controller is deallocated.
//    RACSignal *signal2 = RACAble(obj.arrayController, items);
//
//    @weakify(self);
//    RACSignal *signal3 = [anotherSignal flattenMap:^(NSArrayController *arrayController) {
//        // Avoids a retain cycle.
//        @strongify(self);
//        return RACAble(arrayController, items);
//    }];
//
// Returns a signal which sends a value every time the value at the given key
// path changes, and sends completed if self is deallocated (no matter which
// variant of RACAble was used).
#define RACAble(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (_RACAbleObject(self, __VA_ARGS__)) \
        (_RACAbleObject(__VA_ARGS__))

// Do not use this directly. Use RACAble above.
#define _RACAbleObject(object, property) [object rac_signalForKeyPath:@keypath(object, property) observer:self]

// Same as RACAble, but the signal also starts with the current value of the
// property.
#define RACAbleWithStart(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (_RACAbleWithStartObject(self, __VA_ARGS__)) \
        (_RACAbleWithStartObject(__VA_ARGS__))

// Do not use this directly. Use RACAbleWithStart above.
#define _RACAbleWithStartObject(object, property) [object rac_signalWithStartingValueForKeyPath:@keypath(object, property) observer:self]

@class RACDisposable;
@class RACSignal;

@interface NSObject (RACPropertySubscribing)

// Creates a signal to observe the value at the given keypath on the source
// object.
//
// Returns a signal that sends future changes to the object's value at the given keypath.
+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer;

// Creates a signal to observe the value at the given keypath on the source
// object.
//
// Returns a signal that immediately sends the object's current value at the
// given keypath, then any changes thereafter.
+ (RACSignal *)rac_signalWithStartingValueFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer;

// Creates a signal to observe the value at the given keypath on the source
// object.
//
// Returns a signal that sends the change dictionary for each KVO callback.
+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer;

// Creates a signal to observe the value at the given keypath.
//
// Returns a signal that sends future changes to the receiver's value at the given keypath.
- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer;

// Creates a signal to observe the value at the given keypath.
//
// Returns a signal that immediately sends the receiver's current value at the
// given keypath, then any changes thereafter.
- (RACSignal *)rac_signalWithStartingValueForKeyPath:(NSString *)keyPath observer:(NSObject *)observer;

// Keeps the value of the KVC-compliant keypath up-to-date with the latest value
// sent by the signal.
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal;

@end
