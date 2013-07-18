//
//  UITextField+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UITextField+RACSignalSupport.h"
#import "RACSignal.h"
#import "UIControl+RACSignalSupport.h"
#import "NSObject+RACDescription.h"

@implementation UITextField (RACSignalSupport)

- (RACSignal *)rac_textSignal {
	return [[[[self rac_signalForControlEvents:UIControlEventEditingChanged]
		map:^(UITextField *x) {
			return x.text;
		}]
		startWith:self.text]
		setNameWithFormat:@"%@ -rac_textSignal", [self rac_description]];
}

@end
