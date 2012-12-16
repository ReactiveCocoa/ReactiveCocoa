//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
@class RACDisposable, RACTuple;
@protocol RACSignal, RACSubscriber;


// Represents the end-point of a two-way data binding.
@interface RACBindingPoint : NSObject

// Returns a binding point for the given key path on the given target.
+ (instancetype)bindingPointFor:(id)target keyPath:(NSString *)keyPath;

// Creates a new binding point based on the receiver by transforming the
// outbound and inbound signals.
//
// signalsTransformer - A block that takes as a parameter a RACTuple of two
//                      signals and returns a RACTuple of two signals. In each
//                      tuple the first signal is the outbound signal, which
//                      carries values away from the binding point, and the
//                      second one is the inbound signal, which carries values
//                      towards the binding point. The block may return a new
//                      signal based on the old one for either or both of them.
- (instancetype)bindingPointByTransformingSignals:(RACTuple *(^)(RACTuple *))signalsTransformer;

// Creates a new two-way data binding between the receiver and `bindingPoint`.
//
// Upon creation, the value of the key path of `bindingPoint`s target will be
// sent to the receiver's target, after that changes to either target will be
// sent to the other one. Both the receiver's target and the `bindingPoint`s
// target will keep a strong reference to the binding, and will automatically
// dispose of it when either deallocates.
//
// Returns a disposable that may be used to dispose of the binding.
- (RACDisposable *)bindingWithOtherPoint:(RACBindingPoint *)bindingPoint;

@end

@interface NSObject (RACBinding)

// Returns a RACBindingPoint with the receiver as `target`, and with the given
// `keyPath`.
- (RACBindingPoint *)rac_bindingPointForKeyPath:(NSString *)keyPath;

@end
