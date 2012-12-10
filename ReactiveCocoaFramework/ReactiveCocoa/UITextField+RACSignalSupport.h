//
//  UITextField+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol RACSignal;

@interface UITextField (RACSignalSupport)

// Creates and returns a signal for the text of the field. It always starts with
// the current text.
- (id<RACSignal>)rac_textSignal;

@end
