//
//  RACSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACStream.h"
#import "RACSignalProtocol.h"

@class RACDisposable;
@class RACScheduler;
@class RACSubject;
@protocol RACSubscriber;

@interface RACSignal : NSObject <RACSignal>

// Creates a new signal. This is the preferred way to create a new signal
// operation or behavior.
//
// Events can be sent to new subscribers immediately in the `didSubscribe`
// block, but the subscriber will not be able to dispose of the signal until
// a RACDisposable is returned from `didSubscribe`. In the case of infinite
// signals, this won't _ever_ happen if events are sent immediately.
//
// To ensure that the signal is disposable, events can be scheduled on the
// +[RACScheduler currentScheduler] (so that they're deferred, not sent
// immediately), or they can be sent in the background. The RACDisposable
// returned by the `didSubscribe` block should cancel any such scheduling or
// asynchronous work.
//
// didSubscribe - Called when the signal is subscribed to. The new subscriber is
//                passed in. You can then manually control the <RACSubscriber> by
//                sending it -sendNext:, -sendError:, and -sendCompleted,
//                as defined by the operation you're implementing. This block
//                should return a RACDisposable which cancels any ongoing work
//                triggered by the subscription, and cleans up any resources or
//                disposables created as part of it. When the disposable is
//                disposed of, the signal must not send any more events to the
//                `subscriber`. If no cleanup is necessary, return nil.
//
// **Note:** The `didSubscribe` block is called every time a new subscriber
// subscribes. Any side effects within the block will thus execute once for each
// subscription, not necessarily on one thread, and possibly even
// simultaneously!
+ (id<RACSignal>)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe;

// Returns a signal that immediately sends the given value and then completes.
+ (id<RACSignal>)return:(id)value;

// Returns a signal that immediately sends the given error.
+ (id<RACSignal>)error:(NSError *)error;

// Returns a signal that immediately completes.
+ (id<RACSignal>)empty;

// Returns a signal that never completes.
+ (id<RACSignal>)never;

// Returns a signal that calls the block in a background queue. The
// block's success is YES by default. If the block sets success = NO, the
// signal sends error with the error passed in by reference.
+ (id<RACSignal>)start:(id (^)(BOOL *success, NSError **error))block;

// Returns a signal that calls the block with the given scheduler. The
// block's success is YES by default. If the block sets success = NO, the
// signal sends error with the error passed in by reference.
+ (id<RACSignal>)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block;

// Starts and returns an async signal. It calls the block with the given
// scheduler and gives the block the subject that was returned from the method.
// The block can send events using the subject.
+ (id<RACSignal>)startWithScheduler:(RACScheduler *)scheduler subjectBlock:(void (^)(RACSubject *subject))block;

// Subscribes to `signal` when the source signal completes.
- (id<RACSignal>)concat:(id<RACSignal>)signal;

@end
