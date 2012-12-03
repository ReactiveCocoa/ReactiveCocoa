//
//  NSObject+RACBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACSignal;
@class RACDisposable;

typedef id<RACSignal> (^RACSignalTransformationBlock)(id<RACSignal>);
extern RACSignalTransformationBlock const RACSignalTransformationIdentity;

@interface NSObject (RACBindings)

// Create a two-way binding between `receiverKeyPath` on the receiver and
// `otherKeyPath` on `otherObject`.
//
// `receiverKeyPath` on the receiver will be updated with the value of
// `otherKeyPath` on `otherObject`. After that, the two properties will be kept
// in sync by forwarding changes to one onto the other.
//
// receiverSignalBlock - The block that transforms the signal that forwards
//                       changes from `otherObject` to the receiver.
// otherSignalBlock    - The block that transforms the signal that forwards
//                       changes from the receiver to `otherObject`.
//
// Returns a disposable that can be used to sever the binding.
- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath signalBlock:(RACSignalTransformationBlock)receiverSignalBlock toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath signalBlock:(RACSignalTransformationBlock)otherSignalBlock;

@end
