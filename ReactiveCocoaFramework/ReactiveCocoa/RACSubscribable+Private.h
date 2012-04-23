//
//  RACSubscribable+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"

@class RACDisposable;


@interface RACSubscribable ()

@property (nonatomic, copy) RACDisposable * (^didSubscribe)(id<RACSubscriber> subscriber);
@property (nonatomic, strong) NSMutableArray *subscribers;

- (void)performBlockOnEachSubscriber:(void (^)(id<RACSubscriber> subscriber))block;

- (void)tearDown;

@end
