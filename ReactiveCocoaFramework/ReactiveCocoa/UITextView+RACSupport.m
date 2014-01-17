//
//  UITextView+RACSupport.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSupport.h"

#import "EXTScope.h"
#import "NSNotificationCenter+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"

#import <objc/runtime.h>

@implementation UITextView (RACSupport)

- (RACSignal *)rac_textSignal {
	RACSignal *noteSignal = [[NSNotificationCenter.defaultCenter
		rac_addObserverForName:UITextViewTextDidChangeNotification object:self]
		map:^(NSNotification *note) {
			UITextView *textView = note.object;
			return textView.text;
		}];

	@weakify(self);

	RACSignal *signal = [[[[RACSignal
		defer:^{
			@strongify(self);
			return [RACSignal return:self.text];
		}]
		concat:noteSignal]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_textSignal", self.rac_description];

	return signal;
}
@end

@implementation UITextView (RACSupportDeprecated)

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(UITextViewDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return proxy;
}
@end
