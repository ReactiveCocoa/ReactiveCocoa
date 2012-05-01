//
//  UIControl+RACSubscribableSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSubscribable;


@interface UIControl (RACSubscribableSupport)

// Creates and returns a subscribable that sends the sender of the control event
// whenever one of the control events is triggered.
- (RACSubscribable *)rac_subscribableForControlEvents:(UIControlEvents)controlEvents;

@end
