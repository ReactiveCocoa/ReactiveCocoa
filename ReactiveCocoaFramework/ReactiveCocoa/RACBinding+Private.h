//
//  RACBinding+Private.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"

@interface RACBinding ()

- (instancetype)initWithSignal:(RACSignal *)signal subscriber:(id<RACSubscriber>)subscriber;

@end
