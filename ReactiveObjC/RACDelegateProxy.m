//
//  RACDelegateProxy.m
//  ReactiveObjC
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDelegateProxy.h"
#import "NSObject+RACSelectorSignal.h"
#import <objc/runtime.h>

@interface RACDelegateProxy () {
	// Declared as an ivar to avoid method naming conflicts.
	Protocol *_protocol;
}

@end

@implementation RACDelegateProxy

#pragma mark Lifecycle

- (instancetype)initWithProtocol:(Protocol *)protocol {
	NSCParameterAssert(protocol != NULL);

	self = [super init];
	if (self == nil) return nil;

	class_addProtocol(self.class, protocol);

	_protocol = protocol;

	return self;
}

#pragma mark API

- (RACSignal *)signalForSelector:(SEL)selector {
	return [self rac_signalForSelector:selector fromProtocol:_protocol];
}

#pragma mark NSObject

- (BOOL)isProxy {
	return YES;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
	[invocation invokeWithTarget:self.rac_proxiedDelegate];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	// Look for the selector as an optional instance method.
	struct objc_method_description methodDescription = protocol_getMethodDescription(_protocol, selector, NO, YES);

	if (methodDescription.name == NULL) {
		// Then fall back to looking for a required instance
		// method.
		methodDescription = protocol_getMethodDescription(_protocol, selector, YES, YES);
		if (methodDescription.name == NULL) return [super methodSignatureForSelector:selector];
	}

	return [NSMethodSignature signatureWithObjCTypes:methodDescription.types];
}

- (BOOL)respondsToSelector:(SEL)selector {
	// Add the delegate to the autorelease pool, so it doesn't get deallocated
	// between this method call and -forwardInvocation:.
	__autoreleasing id delegate = self.rac_proxiedDelegate;
	if ([delegate respondsToSelector:selector]) return YES;
    
	return [super respondsToSelector:selector];
}

@end
