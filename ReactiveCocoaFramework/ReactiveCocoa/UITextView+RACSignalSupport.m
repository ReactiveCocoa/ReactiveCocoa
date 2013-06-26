//
//  UITextView+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSignalSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import <objc/runtime.h>

@implementation UITextView (RACSignalSupport)

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithDelegator:self protocol:@protocol(UITextViewDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return proxy;
}

- (RACSignal *)rac_textSignal {
	[self.rac_delegateProxy assignAsDelegate];

	@weakify(self);
	return [[[[RACSignal
		defer:^{
			@strongify(self);
			return [RACSignal return:self];
		}]
		concat:[self.rac_delegateProxy signalForSelector:@selector(textViewDidChange:)]]
		reduceEach:^(UITextView *x) {
			return x.text;
		}]
		setNameWithFormat:@"%@ -rac_textSignal", self];
}

@end
