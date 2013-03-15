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

// Returns a signal that will complete after the receiver has been deallocated.
- (RACSignal *)rac_didDeallocSignal;

@end
