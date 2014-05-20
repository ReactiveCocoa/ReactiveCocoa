//
//  UIGestureRecognizer+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Josh Vera on 5/5/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

@interface UIGestureRecognizer (RACSignalSupport)

/// Returns a signal that sends the receiver when its gesture occurs.
- (RACSignal *)rac_gestureSignal;

@end
