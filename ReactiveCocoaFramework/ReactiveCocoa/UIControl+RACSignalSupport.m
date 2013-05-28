//
//  UIControl+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSignalSupport.h"
#import "RACEventTrampoline.h"

@implementation UIControl (RACSignalSupport)

- (RACSignal *)rac_signalForControlEvents:(UIControlEvents)controlEvents {
	RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForControl:self controlEvents:controlEvents];
	[trampoline.subject setNameWithFormat:@"%@ -rac_signalForControlEvents: %lx", self, (unsigned long)controlEvents];
	RACAddEventTrampoline(self, trampoline);
	
	return trampoline.subject;
}

@end
