//
//  RACSubscribable+Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubscribable.h"

@class RACDisposable;


@interface RACSubscribable ()

@property (nonatomic, copy) RACDisposable * (^didSubscribe)(id<RACSubscriber> observer);
@property (nonatomic, strong) NSMutableArray *subscribers;

@end
