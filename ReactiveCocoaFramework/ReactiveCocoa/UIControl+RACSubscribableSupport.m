//
//  UIControl+RACSubscribableSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "UIControl+RACSubscribableSupport.h"
#import "RACSubject.h"
#import <objc/runtime.h>

@interface RACControlEventTrampoline : NSObject
@property (nonatomic, strong) RACSubject *subject;
@end

@implementation RACControlEventTrampoline

@synthesize subject;

+ (RACControlEventTrampoline *)trampolineForControl:(UIControl *)control ControlEvents:(UIControlEvents)controlEvents {
	RACControlEventTrampoline *trampoline = [[self alloc] init];
	[control addTarget:trampoline action:@selector(didGetControlEvent:) forControlEvents:controlEvents];
	return trampoline;
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.subject = [RACSubject subject];
	
	return self;
}

- (void)didGetControlEvent:(id)sender {
	[self.subject sendNext:sender];
}

@end


const void *RACUIControlEventTrampolinesKey = "RACUIControlEventTrampolinesKey";

@implementation UIControl (RACSubscribableSupport)

- (RACSubscribable *)rac_subscribableForControlEvents:(UIControlEvents)controlEvents {
	RACControlEventTrampoline *trampoline = [RACControlEventTrampoline trampolineForControl:self ControlEvents:controlEvents];
	NSMutableSet *controlEventTrampolines = objc_getAssociatedObject(self, RACUIControlEventTrampolinesKey);
	if(controlEventTrampolines == nil) {
		controlEventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(self, RACUIControlEventTrampolinesKey, controlEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	[controlEventTrampolines addObject:trampoline];
	
	return trampoline.subject;
}

@end
