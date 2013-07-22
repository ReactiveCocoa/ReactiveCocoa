//
//  RACKVOBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"
#import "EXTKeyPathCoding.h"
#import "metamacros.h"

// Creates a RACKVOBinding to the given key path. When the targeted object
// deallocates, the binding will complete.
//
// If RACBind() is used on the left-hand side of an assignment, there must a
// RACBinding on the right-hand side of the assignment. Values originating from
// the left side are considered to be rumors, and values originating from the
// right side are considered to be facts.
//
// There are two different versions of this macro:
//
//  - RACBind(TARGET, KEYPATH, NILVALUE) will create a binding to the `KEYPATH`
//    of `TARGET`. If the `rumorsSubscriber` is ever sent a `nil` value, the
//    property will be set to `NILVALUE` instead. `NILVALUE` may itself be `nil`
//    for object properties, but an NSValue should be used for primitive
//    properties, to avoid an exception if `nil` is sent (which might occur if
//    an intermediate object is set to `nil`).
//  - RACBind(TARGET, KEYPATH) is the same as the above, but `NILVALUE` defaults to
//    `nil`.
//
// Examples
//
//  RACKVOBinding *objectBinding = RACBind(self, objectProperty);
//  RACKVOBinding *integerBinding = RACBind(self, integerProperty, @42);
//
//  RACBind(view, objectProperty) = RACBind(model, objectProperty);
//  RACBind(view, integerProperty, @2) = RACBind(model, integerProperty, @10);
#define RACBind(TARGET, ...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RACBind_(TARGET, __VA_ARGS__, nil)) \
        (RACBind_(TARGET, __VA_ARGS__))

// Do not use this directly. Use the RACBind macro above.
#define RACBind_(TARGET, KEYPATH, NILVALUE) \
    [[RACKVOBinding alloc] initWithTarget:(TARGET) keyPath:@keypath(TARGET, KEYPATH) nilValue:(NILVALUE)][@""]

// A RACBinding that observes a KVO-compliant key path for changes.
@interface RACKVOBinding : RACBinding

// Initializes a binding that will observe the given object and key path.
//
// Whenever a KVO notification is generated for the key path, the new value is
// assumed to be a fact, and will be sent upon the `factsSignal`. When the
// object deallocates, the binding will complete.
//
// Whenever a rumor is received, it will be set at the given key path using
// key-value coding. A KVO binding receiving an error on `rumorsSignal` is
// considered undefined behavior.
//
// This is the designated initializer for this class.
//
// target   - The object to bind to.
// keyPath  - The key path to observe for new facts, and set when new rumors are
//            received.
// nilValue - The value to set at the key path whenever a `nil` rumor is
//            received. This may be nil when binding to object properties, but
//            an NSValue should be used for primitive properties, to avoid an
//            exception if `nil` is received (which might occur if an intermediate
//            object is set to `nil`).
- (id)initWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue;

+ (instancetype)new __attribute__((unavailable("Use -initWithTarget:keyPath:nilValue: instead")));
- (id)init __attribute__((unavailable("Use -initWithTarget:keyPath:nilValue: instead")));

@end

// Methods needed for the convenience macro. Do not call explicitly.
@interface RACKVOBinding (RACBind)

- (instancetype)objectForKeyedSubscript:(NSString *)unused;
- (void)setObject:(RACBinding *)binding forKeyedSubscript:(NSString *)unused;

@end
