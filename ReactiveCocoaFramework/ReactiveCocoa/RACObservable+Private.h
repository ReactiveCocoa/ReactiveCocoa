//
//  RACObservable_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/15/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObservable.h"

@class RACDisposable;


@interface RACObservable ()

@property (nonatomic, copy) RACDisposable * (^didSubscribe)(id<RACObserver> observer);

@end
