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

@implementation UITextField (RACSignalSupport)

- (RACSignal *)rac_textSignal {
	RACSignal *signal = [[[self rac_signalForControlEvents:UIControlEventEditingChanged] startWith:self] map:^(UITextField *x) {
		return x.text;
	}];

	signal.name = [NSString stringWithFormat:@"%@ -rac_textSignal", self];
	return signal;
}

@end
