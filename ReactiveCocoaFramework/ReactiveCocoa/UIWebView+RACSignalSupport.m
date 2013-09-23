//
//  UIWebView+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Jackson Harper on 9/23/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIWebView+RACSignalSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import "NSObject+RACDescription.h"
#import <objc/runtime.h>

@implementation UIWebView (RACSignalSupport)


static void RACUseDelegateProxy(UIWebView *self) {
    if (self.delegate == self.rac_delegateProxy) return;

    self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
    self.delegate = (id)self.rac_delegateProxy;
}

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(UIWebViewDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	return proxy;
}

- (RACSignal *)rac_loadedSignal {

	RACSignal *loaded = [[self.rac_delegateProxy
		signalForSelector:@selector(webViewDidFinishLoad:)]
		reduceEach:^(UIWebView *webview){
			return [webview request];
		}];

	RACSignal *failed = [[[[self.rac_delegateProxy
		signalForSelector:@selector(webView:didFailLoadWithError:)]
		reduceEach:^(UIWebView *webview, NSError *error) {
			return error;
		}] filter:^BOOL(NSError *error) {
			// This error comes up almost every time you load html
			NSURL *failingURL = [error.userInfo objectForKey:@"NSErrorFailingURLKey"];
			return ![failingURL.absoluteString isEqualToString:@"about:blank"];
		}]
		flattenMap:^(NSError *error) {
			return [RACSignal error:error];
		}];

	RACUseDelegateProxy(self);

	return [[[RACSignal merge:@[ loaded , failed ]]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_loadedSignal", self];
}

@end
