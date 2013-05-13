//
//  UIGestureRecognizer+RACSignalSupport.m
//  Talks
//
//  Created by Josh Vera on 5/5/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import "UIGestureRecognizer+RACSignalSupport.h"
#import "RACEventTrampoline.h"
#import <objc/runtime.h>

@implementation UIGestureRecognizer (RACSignalSupport)

- (RACSignal *)rac_gestureSignal {
	RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForGestureRecognizer:self];
	[trampoline.subject setNameWithFormat:@"%@ -rac_gestureSignal", self];

	NSMutableSet *controlEventTrampolines = objc_getAssociatedObject(self, RACEventTrampolinesKey);
	if (controlEventTrampolines == nil) {
		controlEventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(self, RACEventTrampolinesKey, controlEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	[controlEventTrampolines addObject:trampoline];
	
	return trampoline.subject;
}

@end
