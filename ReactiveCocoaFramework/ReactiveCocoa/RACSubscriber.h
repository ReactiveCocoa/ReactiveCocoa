//
//  RACSubscriber.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACSubscribable.h"

@protocol RACSubscribable;
@class RACDisposable;

@protocol RACSubscriber <NSObject>
- (void)sendNext:(id)value;
- (void)sendError:(NSError *)error;
- (void)sendCompleted;
- (void)didSubscribeWithDisposable:(RACDisposable *)disposable;
@end


@interface RACSubscriber : NSObject <RACSubscriber>

// Creates a new subscriber with the given blocks.
+ (id)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed;

@end
