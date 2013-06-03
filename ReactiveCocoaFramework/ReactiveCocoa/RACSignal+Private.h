//
//  RACSignal+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACSignal.h>

@interface RACSignal ()

@property (atomic, assign, readonly) NSUInteger subscriberCount;

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block;

@end
