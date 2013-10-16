//
//  CLLocationManager+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "CLLocationManager+RACSignalSupport.h"
#import "RACDelegateProxy.h"
#import <objc/runtime.h>

@implementation CLLocationManager (RACSignalSupport)

static void RACUseDelegateProxy(CLLocationManager *self) {
	if (self.delegate == self.rac_delegateProxy) return;

	self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
	self.delegate = (id)self.rac_delegateProxy;
}

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy != nil) return proxy;

	proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(CLLocationManagerDelegate)];
	objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return proxy;
}

@end
