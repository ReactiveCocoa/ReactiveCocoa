//
//  UIGestureRecognizer+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Vera on 5/5/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACAction;
@class RACSignal;

@interface UIGestureRecognizer (RACSupport)

/// Sends the receiver whenever its gesture occurs.
@property (nonatomic, strong, readonly) RACSignal *rac_gestureSignal;

/// An action to execute whenever the recognizer's gesture occurs.
///
/// The receiver will be automatically enabled and disabled based on
/// `RACAction.enabled`.
@property (nonatomic, strong) RACAction *rac_action;

@end
