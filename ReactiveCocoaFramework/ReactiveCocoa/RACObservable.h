//
//  RACObservable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACObserver;


@protocol RACObservable <NSObject>
// Subscribes observer to changes on the receiver. The receiver defines which events it actually sends and in what situations the events are sent.
- (id<RACObserver>)subscribe:(id<RACObserver>)observer;

// Unsubscribes the observer.
- (void)unsubscribe:(id<RACObserver>)observer;
@end


@interface RACObservable : NSObject <RACObservable>

+ (id)createObservable:(id<RACObserver> (^)(id<RACObserver> observer))didSubscribe;
+ (id)return:(id)value;
+ (id)error:(NSError *)error;
+ (id)complete;
+ (id)none;

// Convenience method to subscribe to the `next` event.
- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock;

// Convenience method to subscribe to the `next` and `completed` events.
- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to the `next`, `completed`, and `error` events.
- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock completed:(void (^)(void))completedBlock;

// Convenience method to subscribe to `error` events.
- (id<RACObserver>)subscribeError:(void (^)(NSError *error))errorBlock;

// Convenience method to subscribe to `completed` events.
- (id<RACObserver>)subscribeCompleted:(void (^)(void))completedBlock;

// Convenience method to subscribe to `next` and `error` events.
- (id<RACObserver>)subscribeNext:(void (^)(id x))nextBlock error:(void (^)(NSError *error))errorBlock;

@end
