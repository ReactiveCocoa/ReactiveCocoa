//
//  UIActionSheet+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-06-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIActionSheet+RACSignalSupport.h"
#import "RACDelegateProxy.h"
#import "RACSignal.h"
#import "RACTuple.h"
#import <objc/runtime.h>

@implementation UIActionSheet (RACSignalSupport)

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithDelegator:self protocol:@protocol(UIActionSheetDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return proxy;
}

- (RACSignal *)rac_buttonClickedSignal {
	[self.rac_delegateProxy assignAsDelegate];

	return [[[self.rac_delegateProxy
		signalForSelector:@selector(actionSheet:clickedButtonAtIndex:)]
		map:^(RACTuple *arguments) {
			return arguments.second; // button index
		}]
		setNameWithFormat:@"%@ -rac_buttonClickedSignal", self];
}

@end
