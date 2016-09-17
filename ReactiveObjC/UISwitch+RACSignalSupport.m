//
//  UISwitch+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UISwitch+RACSignalSupport.h"
#import <ReactiveObjC/EXTKeyPathCoding.h>
#import "UIControl+RACSignalSupportPrivate.h"

@implementation UISwitch (RACSignalSupport)

- (RACChannelTerminal *)rac_newOnChannel {
	return [self rac_channelForControlEvents:UIControlEventValueChanged key:@keypath(self.on) nilValue:@NO];
}

@end
