//
//  UISwitch+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACChannelTerminal;

@interface UISwitch (RACSignalSupport)

// Creates and returns a RACChannelTerminal that sends whether the receiver is
// on whenever the UIControlEventValueChanged control event is fired, and sets
// it on or off when it receives @YES or @NO respectively. If it receives `nil`,
// it sets the receiver on or off depending on `nilValue` instead.
- (RACChannelTerminal *)rac_onChannelWithNilValue:(id)nilValue;

@end
