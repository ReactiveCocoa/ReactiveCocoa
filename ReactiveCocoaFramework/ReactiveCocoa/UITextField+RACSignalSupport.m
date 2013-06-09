//
//  UITextField+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UITextField+RACSignalSupport.h"
#import "RACEventTrampoline.h"
#import "UIControl+RACSignalSupport.h"

@implementation UITextField (RACSignalSupport)

- (RACSignal *)rac_signalForDelegateMethod:(SEL)method {
    RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForTextField:self delegateMethod:method];
	[trampoline.subject setNameWithFormat:@"%@ -rac_signalForDelegateMethod: (%@)", self, NSStringFromSelector(method)];
	RACAddEventTrampoline(self, trampoline);
	
	return trampoline.subject;
}

- (RACSignal *)rac_textSignal {
	return [[[[self rac_signalForControlEvents:UIControlEventEditingChanged]
		map:^(UITextField *x) {
			return x.text;
		}]
		startWith:self.text]
		setNameWithFormat:@"%@ -rac_textSignal", self];
}

@end
