//
//  UIPickerView+RACChannelSupport.m
//  ReactiveCocoa
//
//  Created by Denis Mikhaylov on 06.04.14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "UIPickerView+RACChannelSupport.h"
#import "EXTScope.h"
#import "EXTKeyPathCoding.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import "RACChannel.h"
#import "RACTuple.h"
#import "NSObject+RACDeallocating.h"
#import <objc/runtime.h>

@implementation UIPickerView (RACChannelSupport)
static void RACUseDelegateProxy(UIPickerView *self) {
	if (self.delegate == self.rac_delegateProxy) return;
	
	self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
	self.delegate = (id)self.rac_delegateProxy;
}

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(UIPickerViewDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	return proxy;
}

- (RACChannelTerminal *)rac_channelForSelectedRowInComponent:(NSInteger)component {
	RACChannel *channel = [[RACChannel alloc] init];
	@weakify(self);
	[[[[[self
	 rac_delegateProxy]
	 signalForSelector:@selector(pickerView:didSelectRow:inComponent:)]
	 flattenMap:^(RACTuple *args) {
		 if ([args.third integerValue] != component) return [RACSignal empty];
	   
		 return [RACSignal return:args.second];
	 }]
	 takeUntil:self.rac_willDeallocSignal]
	 subscribe:channel.followingTerminal];
	
	[[channel.followingTerminal
	  takeUntil:self.rac_willDeallocSignal]
	  subscribeNext:^(NSNumber *row) {
		  @strongify(self);
		  [self selectRow:row.integerValue inComponent:component animated:NO];
	  }];
	
	RACUseDelegateProxy(self);
	return channel.leadingTerminal;
}
@end
