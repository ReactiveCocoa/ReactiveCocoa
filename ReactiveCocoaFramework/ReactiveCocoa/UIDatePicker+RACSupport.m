//
//  UIDatePicker+RACSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIDatePicker+RACSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSupport.h"
#import "UIControl+RACSupportPrivate.h"

@implementation UIDatePicker (RACSupport)

- (RACChannelTerminal *)rac_newDateChannelWithNilValue:(NSDate *)nilValue {
	return [self rac_channelForControlEvents:UIControlEventValueChanged key:@keypath(self.date) nilValue:nilValue];
}

@end
