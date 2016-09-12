//
//  UIImagePickerController+RACSignalSupport.m
//  ReactiveObjC
//
//  Created by Timur Kuchkarov on 28.03.14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

#import "UIImagePickerController+RACSignalSupport.h"
#import "RACDelegateProxy.h"
#import "RACSignal+Operations.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import <objc/runtime.h>

@implementation UIImagePickerController (RACSignalSupport)

static void RACUseDelegateProxy(UIImagePickerController *self) {
	if (self.delegate == self.rac_delegateProxy) return;
    
	self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
	self.delegate = (id)self.rac_delegateProxy;
}

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy == nil) {
		proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(UIImagePickerControllerDelegate)];
		objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
    
	return proxy;
}

- (RACSignal *)rac_imageSelectedSignal {
	RACSignal *pickerCancelledSignal = [[self.rac_delegateProxy
		signalForSelector:@selector(imagePickerControllerDidCancel:)]
		merge:self.rac_willDeallocSignal];
		
	RACSignal *imagePickerSignal = [[[[self.rac_delegateProxy
		signalForSelector:@selector(imagePickerController:didFinishPickingMediaWithInfo:)]
		reduceEach:^(UIImagePickerController *pickerController, NSDictionary *userInfo) {
			return userInfo;
		}]
		takeUntil:pickerCancelledSignal]
		setNameWithFormat:@"%@ -rac_imageSelectedSignal", RACDescription(self)];
    
	RACUseDelegateProxy(self);
    
	return imagePickerSignal;
}

@end
