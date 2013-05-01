//
//  RACDelegateProxy.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDelegateProxy.h"
#import "RACObjCRuntime.h"
#import "RACEventTrampoline.h"

@interface RACDelegateProxy ()

@property (nonatomic, strong) Protocol *protocol;
@property (nonatomic, weak) NSObject *delegator;
@property (nonatomic, readonly, strong) NSMutableSet *trampolines;

- (BOOL)trampolinesRespondToSelector:(SEL)aSelector;

@end

@implementation RACDelegateProxy

+ (instancetype)proxyWithProtocol:(Protocol *)protocol andDelegator:(NSObject *)delegator {
	if (![self conformsToProtocol:protocol]) {
		class_addProtocol(self.class, protocol);
	}
    
	RACDelegateProxy *proxy = [[self alloc] init];
	proxy.protocol = protocol;
	proxy.delegator = delegator;
	return proxy;
}

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;

	_trampolines = [[NSMutableSet alloc] init];

	return self;
}

- (BOOL)respondsToSelector:(SEL)selector {
	// Add the original delegate to the autorelease pool, so it doesn't get
	// deallocated between this method call and -forwardInvocation:.
	__autoreleasing id actual = self.actualDelegate;
	if ([actual respondsToSelector:selector] || [self trampolinesRespondToSelector:selector]) return YES;
    
	return [super respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	return [NSMethodSignature signatureWithObjCTypes:[RACObjCRuntime getMethodTypesForMethod:selector inProtocol:self.protocol]];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	SEL selector = invocation.selector;
	for (RACEventTrampoline *trampoline in self.trampolines) {
		[trampoline didGetDelegateEvent:selector sender:self.delegator];
	}

	id actual = self.actualDelegate;
	if ([actual respondsToSelector:selector]) {
		[invocation invokeWithTarget:actual];
	}
}

- (void)addTrampoline:(RACEventTrampoline *)trampoline {
	trampoline.proxy = self;
	[self.trampolines addObject:trampoline];
}

- (BOOL)trampolinesRespondToSelector:(SEL)selector {
	for (RACEventTrampoline *trampoline in self.trampolines) {
		if (trampoline.delegateMethod == selector) {
			return YES;
		}
	}
    
	return NO;
}

@end
