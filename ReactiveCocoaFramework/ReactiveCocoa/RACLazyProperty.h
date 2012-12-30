//
//  RACLazyProperty.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface RACLazyProperty : RACProperty

+ (instancetype)lazyPropertyWithStart:(RACSignal *)start;

@end
