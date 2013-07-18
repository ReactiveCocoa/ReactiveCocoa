//
//  UIGestureRecognizer+RACSignalSupport.m
//  Talks
//
//  Created by Josh Vera on 5/5/13.
//  Copyright (c) 2013 GitHub. All rights reserved.
//

#import "UIGestureRecognizer+RACSignalSupport.h"
#import "RACEventTrampoline.h"
#import "NSObject+RACDescription.h"

@implementation UIGestureRecognizer (RACSignalSupport)

- (RACSignal *)rac_gestureSignal {
	RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForGestureRecognizer:self];
	[trampoline.subject setNameWithFormat:@"%@ -rac_gestureSignal", [self rac_description]];
	RACAddEventTrampoline(self, trampoline);

	return trampoline.subject;
}

@end
