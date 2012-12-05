//
//  NSObject+RACBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable, RACScheduler;

@interface NSObject (RACBindings)

// Create a two-way binding between `receiverKeyPath` on the receiver and
// `otherKeyPath` on `otherObject`.
//
// `receiverKeyPath` on the receiver will be updated with the value of
// `otherKeyPath` on `otherObject`. After that, the two properties will be kept
// in sync by forwarding changes to one onto the other.
//
// WARNING: for this method to work, both properties must return a value equal
// to the last one that has been set, for each value that is set. This excludes
// setting `nil` on scalar properties, even if `-setNilValueForKey:` is
// overridden. In this context, a equals b if both are `nil` or if
// `[a isEqual:b]` returns `YES`.
//
// receiverKeyPath     - The key path of the receiver to bind.
// receiverScheduler   - An optional scheduler on which all accesses to the
//                       receiver will be scheduled. If not specified, the
//                       receiver will be accessed from wherever the binding
//                       target is modified.
// receiverTransformer - An optional block with which to transform values from
//                       the receiver to the binding target. Must be
//                       thread-safe.
// otherObject         - The object with which to bind the receiver.
// otherKeyPath        - The key path of the binding target to bind.
// otherScheduler      - An optional scheduler on which all accesses to the
//                       binding target will be scheduled. if not specified, the
//                       binding target will be accessed from wherever the
//                       receiver is modified.
// otherTransformer    - An optional block with which to transform values from
//                       the binding target to the receiver. Must be
//                       thread-safe.
// 
// Returns a disposable that can be used to sever the binding.
- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath transformer:(id(^)(id value))receiverTransformer onScheduler:(RACScheduler *)receiverScheduler toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath transformer:(id(^)(id value))otherTransformer onScheduler:(RACScheduler *)otherScheduler;

@end
