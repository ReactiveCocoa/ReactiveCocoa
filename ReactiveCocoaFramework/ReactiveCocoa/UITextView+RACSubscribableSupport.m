//
//  UITextView+RACSubscribableSupport.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSubscribableSupport.h"
#import "RACEventTrampoline.h"
#import <objc/runtime.h>

@implementation UITextView (RACSubscribableSupport)

- (RACSubscribable *)rac_subscribableForDelegateMethod:(SEL)method {
    RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForTextView:self delegateMethod:method];
    
	NSMutableSet *controlEventTrampolines = objc_getAssociatedObject(self, RACEventTrampolinesKey);
	if (controlEventTrampolines == nil) {
		controlEventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(self, RACEventTrampolinesKey, controlEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	[controlEventTrampolines addObject:trampoline];
	
	return trampoline.subject;
}

- (RACSubscribable *)rac_textSubscribable {
	return [[[self rac_subscribableForDelegateMethod:@selector(textViewDidChange:)] startWith:self] select:^(UITextView *x) {
		return x.text;
	}];
}

@end
