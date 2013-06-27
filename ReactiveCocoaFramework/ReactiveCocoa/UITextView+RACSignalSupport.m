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
#import "NSObject+RACSelectorSignal.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import <objc/runtime.h>

static void RACUseDelegateProxy(UITextView *self) {
	if (self.delegate == self.rac_delegateProxy) return;

	self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
	self.delegate = (id)self.rac_delegateProxy;
}

@implementation UITextView (RACSignalSupport)

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(UITextViewDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return proxy;
}

- (RACSignal *)rac_textSignal {
	RACUseDelegateProxy(self);

	@weakify(self);
	return [[[[[RACSignal
		defer:^{
			@strongify(self);
			return [RACSignal return:RACTuplePack(self)];
		}]
		concat:[self.rac_delegateProxy rac_signalForSelector:@selector(textViewDidChange:) fromProtocol:@protocol(UITextViewDelegate)]]
		reduceEach:^(UITextView *x) {
			return x.text;
		}]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_textSignal", self];
}

@end
