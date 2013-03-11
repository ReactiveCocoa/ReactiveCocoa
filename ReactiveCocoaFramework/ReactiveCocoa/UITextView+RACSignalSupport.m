//
//  UITextView+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSignalSupport.h"
#import "RACEventTrampoline.h"
#import <objc/runtime.h>

@implementation UITextView (RACSignalSupport)

- (RACSignal *)rac_signalForDelegateMethod:(SEL)method {
    RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForTextView:self delegateMethod:method];
	[trampoline.subject setNameWithFormat:@"%@ -rac_signalForDelegateMethod: (%@)", self, NSStringFromSelector(method)];
    
	NSMutableSet *controlEventTrampolines = objc_getAssociatedObject(self, RACEventTrampolinesKey);
	if (controlEventTrampolines == nil) {
		controlEventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(self, RACEventTrampolinesKey, controlEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	[controlEventTrampolines addObject:trampoline];
	
	return trampoline.subject;
}

- (RACSignal *)rac_textSignal {
	return [[[[self rac_signalForDelegateMethod:@selector(textViewDidChange:)]
		streamByPrependingValue:self]
		streamWithMappedValuesFromBlock:^(UITextView *x) {
			return x.text;
		}]
		setNameWithFormat:@"%@ -rac_textSignal", self];
}

@end
