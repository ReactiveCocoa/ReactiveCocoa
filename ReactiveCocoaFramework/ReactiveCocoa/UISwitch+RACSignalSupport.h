//
//  UISwitch+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACBinding;

@interface UISwitch (RACSignalSupport)

// Creates and returns a RACBinding that sends whether the receiver is currently
// on on subscription and whenever it switches on or off, and sets it on or off
// when it receivers @YES or @NO respectively. If it receives `nil`, it switches
// the receiver on or off depending on `nilValue` instead.
- (RACBinding *)rac_onBindingWithNilValue:(id)nilValue;

@end
