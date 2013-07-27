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
// If RACBind() is used as an expression, it returns a RACBindingTerminal that
// can be used to watch the specified property for changes, and set new values
// for it. The terminal will start with the property's current value upon
// subscription.
//
// If RACBind() is used on the left-hand side of an assignment, there must a
// RACBindingTerminal on the right-hand side of the assignment. The two will be
// subscribed to one another: the property's value is immediately set to the
// value of the binding terminal on the right-hand side, and subsequent changes
// to either terminal will be reflected on the other.
//
// There are two different versions of this macro:
//
//  - RACBind(TARGET, KEYPATH, NILVALUE) will create a binding to the `KEYPATH`
//    of `TARGET`. If the terminal is ever sent a `nil` value, the property will
//    be set to `NILVALUE` instead. `NILVALUE` may itself be `nil` for object
//    properties, but an NSValue should be used for primitive properties, to
//    avoid an exception if `nil` is sent (which might occur if an intermediate
//    object is set to `nil`).
//  - RACBind(TARGET, KEYPATH) is the same as the above, but `NILVALUE` defaults to
//    `nil`.
//
// Examples
//
//  RACBindingTerminal *integerBinding = RACBind(self, integerProperty, @42);
//
//  // Sets self.integerProperty to 5.
//  [integerBinding sendNext:@5];
//
//  // Logs the current value of self.integerProperty, and all future changes.
//  [integerBinding subscribeNext:^(id value) {
//      NSLog(@"value: %@", value);
//  }];
//
//  // Binds properties to each other, taking the initial value from the right
//  side.
//  RACBind(view, objectProperty) = RACBind(model, objectProperty);
//  RACBind(view, integerProperty, @2) = RACBind(model, integerProperty, @10);
#define RACBind(TARGET, ...) \
    metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
        (RACBind_(TARGET, __VA_ARGS__, nil)) \
        (RACBind_(TARGET, __VA_ARGS__))

// Do not use this directly. Use the RACBind macro above.
#define RACBind_(TARGET, KEYPATH, NILVALUE) \
    [[RACKVOBinding alloc] initWithTarget:(TARGET) keyPath:@keypath(TARGET, KEYPATH) nilValue:(NILVALUE)][@keypath(RACKVOBinding.new, followingTerminal)]

// A RACBinding that observes a KVO-compliant key path for changes.
@interface RACKVOBinding : RACBinding

// Initializes a binding that will observe the given object and key path.
//
// The current value of the key path, and future KVO notifications for the given
// key path, will be sent to subscribers of the binding's `followingTerminal`.
// Values sent to the `followingTerminal` will be set at the given key path using
// key-value coding.
//
// When the target object deallocates, the binding will complete. Signal errors
// are considered undefined behavior.
//
// This is the designated initializer for this class.
//
// target   - The object to bind to.
// keyPath  - The key path to observe and set the value of.
// nilValue - The value to set at the key path whenever a `nil` value is
//            received. This may be nil when binding to object properties, but
//            an NSValue should be used for primitive properties, to avoid an
//            exception if `nil` is received (which might occur if an intermediate
//            object is set to `nil`).
- (id)initWithTarget:(NSObject *)target keyPath:(NSString *)keyPath nilValue:(id)nilValue;

- (id)init __attribute__((unavailable("Use -initWithTarget:keyPath:nilValue: instead")));

@end

// Methods needed for the convenience macro. Do not call explicitly.
@interface RACKVOBinding (RACBind)

- (RACBindingTerminal *)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(RACBindingTerminal *)otherTerminal forKeyedSubscript:(NSString *)key;

@end
