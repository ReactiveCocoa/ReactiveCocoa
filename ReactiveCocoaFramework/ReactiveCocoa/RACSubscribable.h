//
//  RACSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSubscribableProtocol.h"

@class RACCancelableSubscribable;
@class RACConnectableSubscribable;
@class RACDisposable;
@class RACScheduler;
@class RACSubject;
@class RACTuple;
@protocol RACSubscriber;

@interface RACSubscribable : NSObject <RACSubscribable>

// The name of the subscribable. This is for debug / human purposes only.
@property (nonatomic, copy) NSString *name;

// Creates a new subscribable. This is the preferred way to create a new
// subscribable operation or behavior.
//
// didSubscribe - called when the subscribable is subscribed to. The new
// subscriber is passed in. You can then manually control the subscriber by
// sending it `-sendNext:`, `-sendError:`, and `-sendCompleted`, as defined by
// the operation you're implementing. The block should return a disposable that
// cleans up all the resources and disposables created by the subscribable.
// This disposable is returned as part of the disposable returned by the
// `-subscribe:` call. When the disposable is disposed of, the subscribable must
// not send any more events to the subscriber. You may return nil if there is no
// cleanup necessary.
//
// *Note* that the `didSubscribe` block is called every time a subscriber subscribes.
+ (instancetype)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe;

// Returns a subscribable that immediately sends the given value and then
// completes.
+ (instancetype)return:(id)value;

// Returns a subscribable that immediately send the given error.
+ (instancetype)error:(NSError *)error;

// Returns a subscribable that immediately completes.
+ (instancetype)empty;

// Returns a subscribable that never completes.
+ (instancetype)never;

// Returns a subscribable that calls the block in a background queue. The
// block's success is YES by default. If the block sets success = NO, the
// subscribable sends error with the error passed in by reference.
+ (RACSubscribable *)start:(id (^)(BOOL *success, NSError **error))block;

// Returns a subscribable that calls the block with the given scheduler. The
// block's success is YES by default. If the block sets success = NO, the
// subscribable sends error with the error passed in by reference.
+ (RACSubscribable *)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block;

// Starts and returns an async subscribable. It calls the block with the given
// scheduler and gives the block the subject that was returned from the method. 
// The block can send events using the subject.
+ (RACSubscribable *)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block;

@end
