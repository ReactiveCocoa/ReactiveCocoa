//
//  UIControl+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

@interface UIControl (RACSupport)

/// Creates and returns a signal that sends the receiver whenever one of the
/// given control events is triggered.
- (RACSignal *)rac_signalForControlEvents:(UIControlEvents)controlEvents;

@end
