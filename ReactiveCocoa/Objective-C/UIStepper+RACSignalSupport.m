//
//  UIStepper+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIStepper+RACSignalSupport.h"
#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import "UIControl+RACSignalSupportPrivate.h"

@implementation UIStepper (RACSignalSupport)

- (RACChannelTerminal *)rac_newValueChannelWithNilValue:(NSNumber *)nilValue {
	return [self rac_channelForControlEvents:UIControlEventValueChanged key:@keypath(self.value) nilValue:nilValue];
}

@end
