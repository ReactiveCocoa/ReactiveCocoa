//
//  RACSubscriber.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACSubscribable.h"

@class RACDisposable;

@protocol RACSubscriber <NSObject>
// Send the next value to subscribers. `value` can be nil.
- (void)sendNext:(id)value;

// Send the error to subscribers. This terminates the subscription.
- (void)sendError:(NSError *)error;

// Send completed to subscribers. This terminates the subscription.
- (void)sendCompleted;

// Sends the subscriber the disposable that represents its subscription.
- (void)didSubscribeWithDisposable:(RACDisposable *)disposable;
@end


@interface RACSubscriber : NSObject <RACSubscriber>

// Creates a new subscriber with the given blocks.
+ (id)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed;

@end
