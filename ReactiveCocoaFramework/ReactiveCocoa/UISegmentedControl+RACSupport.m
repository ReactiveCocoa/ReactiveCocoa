//
//  UISegmentedControl+RACSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UISegmentedControl+RACSupport.h"
#import "EXTKeyPathCoding.h"
#import "UIControl+RACSupport.h"
#import "UIControl+RACSupportPrivate.h"

@implementation UISegmentedControl (RACSupport)

- (RACChannelTerminal *)rac_newSelectedSegmentIndexChannelWithNilValue:(NSNumber *)nilValue {
	return [self rac_channelForControlEvents:UIControlEventValueChanged key:@keypath(self.selectedSegmentIndex) nilValue:nilValue];
}

@end
