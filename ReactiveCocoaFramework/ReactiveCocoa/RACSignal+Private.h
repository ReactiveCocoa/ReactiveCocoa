//
//  RACSignal+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACSignal.h>

@class RACDisposable;

@interface RACSignal ()

@property (nonatomic, copy) RACDisposable * (^didSubscribe)(id<RACSubscriber> subscriber);

// All access to this must be synchronized.
@property (nonatomic, strong) NSMutableArray *subscribers;

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block;

@end
