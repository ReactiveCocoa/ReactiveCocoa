//
//  UIGestureRecognizer+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Travis Jeffery on 5/15/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

@interface UIGestureRecognizer (RACSignalSupport)

// Creates and returns a signal whenever the gesture is recognized,
// the signal sends the gesture recognizer.
- (RACSignal *)rac_signalForGesture;

@end
