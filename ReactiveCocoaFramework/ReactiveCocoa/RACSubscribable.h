//
//  RACSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;
@class RACScheduler;
@class RACSubject;
@protocol RACSubscriber;

@protocol RACSubscribable <NSObject>
// Subscribes subscriber to changes on the receiver. The receiver defines which
// events it actually sends and in what situations the events are sent.
//
// Returns a disposable. You can call -dispose on it if you need to end your
// subscription before it would otherwise end.
- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber;
@end


@interface RACSubscribable : NSObject <RACSubscribable>

// Creates a new subscribable. This is the preferred way to create a new
// subscribable operation or behavior.
//
// didSubscribe - called when the subscribable is subscribed to. The new
// subscriber is passed in. You can then manually control the subscriber by
// sending it -sendNext:, -sendError:, and -sendCompleted, as defined by the
// operation you're implementing. The block should return a disposable that
// cleans up all the resources and disposables created by the subscribable.
// This disposable is returned by the -subscribe: call. You may return nil if
// there is no cleanup necessary.
//
// *Note* that the `didSubscribe` block is called every time a subscriber subscribes.
+ (id)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe;

// Returns a subscribable that immediately sends the given value and then
// completes.
+ (id)return:(id)value;

// Returns a subscribable that immediately send the given error.
+ (id)error:(NSError *)error;

// Returns a subscribable that immediately completes.
+ (id)empty;

// Returns a subscribable that never completes.
+ (id)never;

// Returns a subscribable that calls the block in a background queue. The
// block's success is YES by default. If the block sets success = NO, the
// subscribable sends error with the error passed in by reference.
+ (id)start:(id (^)(BOOL *success, NSError **error))block;

// Returns a subscribable that calls the block with the given scheduler. The
// block's success is YES by default. If the block sets success = NO, the
// subscribable sends error with the error passed in by reference.
+ (id)startWithScheduler:(RACScheduler *)scheduler block:(id (^)(BOOL *success, NSError **error))block;

@end
