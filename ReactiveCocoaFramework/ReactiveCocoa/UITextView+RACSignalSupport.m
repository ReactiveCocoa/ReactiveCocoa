//
//  UITextView+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSignalSupport.h"
#import "RACEventTrampoline.h"
#import "NSObject+RACDescription.h"

@implementation UITextView (RACSignalSupport)

- (RACSignal *)rac_signalForDelegateMethod:(SEL)method {
    RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForTextView:self delegateMethod:method];
	[trampoline.subject setNameWithFormat:@"%@ -rac_signalForDelegateMethod: (%@)", self, NSStringFromSelector(method)];
	RACAddEventTrampoline(self, trampoline);

	return trampoline.subject;
}

- (RACSignal *)rac_textSignal {
	return [[[[self rac_signalForDelegateMethod:@selector(textViewDidChange:)]
		map:^(UITextView *x) {
			return x.text;
		}]
		startWith:self.text]
		setNameWithFormat:@"%@ -rac_textSignal", [self rac_description]];
}

@end
