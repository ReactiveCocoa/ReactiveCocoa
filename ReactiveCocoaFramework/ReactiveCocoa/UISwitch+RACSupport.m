//
//  UISwitch+RACSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UISwitch+RACSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSupport.h"
#import "UIControl+RACSupportPrivate.h"

@implementation UISwitch (RACSupport)

- (RACChannelTerminal *)rac_newOnChannel {
	return [self rac_channelForControlEvents:UIControlEventValueChanged key:@keypath(self.on) nilValue:@NO];
}

@end
