//
//  RACObservable_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable.h"


@interface RACObservable ()

@property (nonatomic, copy) id<RACObserver> (^didSubscribe)(id<RACObserver> observer);

- (void)performBlockOnAllSubscribers:(void (^)(id<RACObserver> observer))block;

@end
