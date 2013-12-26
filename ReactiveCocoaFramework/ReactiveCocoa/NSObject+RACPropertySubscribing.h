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
/// In either case, the observation continues until `TARGET` _or self_ is
/// deallocated. If any intermediate object is deallocated instead, it will be
/// assumed to have been set to nil.
///
/// Make sure to `@strongify(self)` when using this macro within a block! The
/// macro will _always_ reference `self`, which can silently introduce a retain
/// cycle within a block. As a result, you should make sure that `self` is a weak
/// reference (e.g., created by `@weakify` and `@strongify`) before the
/// expression that uses `RACObserve`.
///
/// Examples
///
///    // Observes self, and doesn't stop until self is deallocated.
///    RACSignal *selfSignal = RACObserve(self, arrayController.items);
///
///    // Observes the array controller, and stops when self _or_ the array
///    // controller is deallocated.
///    RACSignal *arrayControllerSignal = RACObserve(self.arrayController, items);
///
///    // Observes obj.arrayController, and stops when self _or_ the array
///    // controller is deallocated.
///    RACSignal *signal2 = RACObserve(obj.arrayController, items);
///
///    @weakify(self);
///    RACSignal *signal3 = [anotherSignal flattenMap:^(NSArrayController *arrayController) {
///        // Avoids a retain cycle because of RACObserve implicitly referencing
///        // self.
///        @strongify(self);
///        return RACObserve(arrayController, items);
///    }];
///
/// Returns a signal which sends the current value of the key path on
/// subscription, then sends the new value every time it changes, and sends
/// completed if self or observer is deallocated.
#define RACObserve(TARGET, KEYPATH) \
    [(id)(TARGET) rac_valuesForKeyPath:@keypath(TARGET, KEYPATH) observer:self]

@class RACDisposable;
@class RACSignal;

@interface NSObject (RACPropertySubscribing)

/// Creates a signal to observe the value at the given key path.
///
/// The initial value is sent on subscription. Subsequent values are sent from
/// whichever thread the change occured on, even if it doesn't have a valid
/// scheduler.
///
/// Returns a signal that immediately sends the receiver's current value at the
/// given keypath, then any changes thereafter.
- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath observer:(NSObject *)observer;

/// Creates a signal to observe the changes to the <RACCollection> at the given
/// key path.
///
/// The initial value is sent on subscription. Subsequent values are sent from
/// whichever thread the change occured on, even if it doesn't have a valid
/// scheduler.
///
/// Examples
///
///     [[[self
///         rac_valuesAndCollectionMutationsForKeyPath:@keypath(self.models) observer:self]
///         reduceEach:^(id _, id<RACOrderedCollectionMutation> modelsMutation) {
///             return [modelsMutation map:^(Model *model) {
///                 return [[ViewModel alloc] initWithModel:model];
///             }];
///         }]
///         subscribeNext:^(id<RACOrderedCollectionMutation> viewModelsMutation) {
///             @strongify(self);
///             
///             NSMutableArray *VMs = [self mutableArrayValueForKey:@keypath(self.viewModels)];
///             [viewModelsMutation mutateCollection:VMs];
///         }];
///
/// Returns a signal that sends tuples containing the current collection at the
/// key path and a <RACCollectionMutation> describing the change that occurred.
/// If the collection is specifically a <RACOrderedCollection>, the collection
/// mutation will conform to <RACOrderedCollectionMutation>.
- (RACSignal *)rac_valuesAndCollectionMutationsForKeyPath:(NSString *)keyPath observer:(NSObject *)observer;

/// Creates a signal to observe the changes of the given key path.
///
/// The initial value (if `NSKeyValueObservingOptionInitial` is specified) is
/// sent on subscription. Subsequent values are sent from whichever thread the
/// change occured on, even if it doesn't have a valid scheduler.
///
/// Returns a signal that sends tuples containing the current value at the key
/// path and the change dictionary for each KVO callback.
- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer;

@end

#define RACAble(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (_RACAbleObject(self, __VA_ARGS__)) \
        (_RACAbleObject(__VA_ARGS__))

#define _RACAbleObject(object, property) [object rac_signalForKeyPath:@keypath(object, property) observer:self]

#define RACAbleWithStart(...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (_RACAbleWithStartObject(self, __VA_ARGS__)) \
        (_RACAbleWithStartObject(__VA_ARGS__))

#define _RACAbleWithStartObject(object, property) [object rac_signalWithStartingValueForKeyPath:@keypath(object, property) observer:self]

@interface NSObject (RACUnavailablePropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
+ (RACSignal *)rac_signalWithStartingValueFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesAndChangesForKeyPath:options:observer: instead.")));
- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
- (RACSignal *)rac_signalWithStartingValueForKeyPath:(NSString *)keyPath observer:(NSObject *)observer __attribute__((unavailable("Use -rac_valuesForKeyPath:observer: or RACObserve() instead.")));
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal __attribute__((unavailable("Use -[RACSignal setKeyPath:onObject:] instead")));

@end
