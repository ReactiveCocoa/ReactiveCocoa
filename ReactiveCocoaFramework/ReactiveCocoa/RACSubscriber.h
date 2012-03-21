//
//  RACSubscriber.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACSubscribable.h"

@protocol RACSubscribable;

@protocol RACSubscriber <NSObject>
- (void)sendNext:(id)value;
- (void)sendError:(NSError *)error;
- (void)sendCompleted;
- (void)didSubscribeToSubscribable:(id<RACSubscribable>)subscribable;
- (void)stopSubscription;
@end


@interface RACSubscriber : NSObject <RACSubscriber>

// Creates a new observer with the given blocks.
+ (id)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed;

@end
