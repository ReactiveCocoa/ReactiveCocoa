//
// Created by Igor Vasilenko on 09/09/16.
// Copyright (c) 2016 GitHub. All rights reserved.
//

#import "UISearchBar+RACSignalSupport.h"

#import <ReactiveCocoa/EXTScope.h>
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import <objc/runtime.h>

@implementation UISearchBar (RACSignalSupport)

static void RACUseDelegateProxy(UISearchBar *self) {
    if (self.delegate == self.rac_delegateProxy) return;

    self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
    self.delegate = (id)self.rac_delegateProxy;
}

- (RACDelegateProxy *)rac_delegateProxy {
    RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
    if (proxy == nil) {
        proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(UISearchBarDelegate)];
        objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return proxy;
}

- (RACSignal *)rac_textSignal {
    @weakify(self);
    RACSignal *signal = [[[[RACSignal defer:^{
        @strongify(self);
        return [self.rac_delegateProxy signalForSelector:@selector(searchBar:textDidChange:)];
    }] reduceEach:^(UISearchBar *searchBar, NSString *searchBarText) {
        return searchBarText;
    }] takeUntil:self.rac_willDeallocSignal] setNameWithFormat:@"%@ -rac_textSignal", RACDescription(self)];

    RACUseDelegateProxy(self);

    return signal;
}

@end
