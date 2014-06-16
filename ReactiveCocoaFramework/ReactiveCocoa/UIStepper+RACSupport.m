//
//  UIStepper+RACSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIStepper+RACSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSupport.h"
#import "UIControl+RACSupportPrivate.h"

@implementation UIStepper (RACSupport)

- (RACChannelTerminal *)rac_newValueChannelWithNilValue:(NSNumber *)nilValue {
	return [self rac_channelForControlEvents:UIControlEventValueChanged key:@keypath(self.value) nilValue:nilValue];
}

@end
