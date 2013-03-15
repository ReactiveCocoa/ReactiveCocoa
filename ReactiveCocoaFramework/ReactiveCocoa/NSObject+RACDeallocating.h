//
//  NSObject+RACDeallocating.h
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@interface NSObject (RACDeallocating)

- (RACSignal *)rac_didDeallocSignal;

@end
