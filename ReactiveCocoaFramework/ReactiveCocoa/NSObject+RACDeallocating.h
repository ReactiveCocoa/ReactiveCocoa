//
//  NSObject+RACDeallocating.h
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACCompoundDisposable;
@class RACDisposable;
@class RACSignal;

@interface NSObject (RACDeallocating)

// The compound disposable which will be disposed of when the receiver is
// deallocated.
@property (atomic, readonly, strong) RACCompoundDisposable *rac_deallocDisposable;

// Returns a signal that will complete immediately before the receiver is fully deallocated.
- (RACSignal *)rac_willDeallocSignal;

// Returns a signal that will complete after the receiver has been deallocated.
- (RACSignal *)rac_didDeallocSignal;

// Adds a disposable which will be disposed when the receiver deallocates.
- (void)rac_addDeallocDisposable:(RACDisposable *)disposable;

@end
