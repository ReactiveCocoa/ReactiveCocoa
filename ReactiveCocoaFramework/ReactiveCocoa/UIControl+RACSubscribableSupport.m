//
//  UIControl+RACSubscribableSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSubscribableSupport.h"
#import "RACEventTrampoline.h"
#import <objc/runtime.h>

@implementation UIControl (RACSubscribableSupport)

- (RACSubscribable *)rac_subscribableForControlEvents:(UIControlEvents)controlEvents {
	RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForControl:self controlEvents:controlEvents];
	NSMutableSet *controlEventTrampolines = objc_getAssociatedObject(self, RACEventTrampolinesKey);
	if (controlEventTrampolines == nil) {
		controlEventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(self, RACEventTrampolinesKey, controlEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	[controlEventTrampolines addObject:trampoline];
	
	return trampoline.subject;
}

@end
