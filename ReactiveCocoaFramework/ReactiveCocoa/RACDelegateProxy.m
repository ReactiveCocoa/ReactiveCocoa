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

@interface RACDelegateProxy (Private)

- (BOOL)trampolinesRespondToSelector:(SEL)aSelector;

@end

@implementation RACDelegateProxy

@synthesize protocol;
@synthesize delegator;
@synthesize actualDelegate;

+ (instancetype)proxyWithProtocol:(Protocol *)protocol andDelegator:(NSObject *)delegator {
    if (![self conformsToProtocol:protocol]) {
        class_addProtocol([self class], protocol);
    }
    
    RACDelegateProxy *proxy = [[self alloc] init];
    [proxy setProtocol:protocol];
    [proxy setDelegator:delegator];
    return proxy;
}

- (instancetype)init {
    if (self = [super init]) {
        trampolines = [[NSMutableSet alloc] init];
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([actualDelegate respondsToSelector:aSelector] || [self trampolinesRespondToSelector:aSelector])
        return YES;
    
    return [super respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [NSMethodSignature signatureWithObjCTypes:
            [RACObjCRuntime getMethodTypesForMethod:aSelector inProtocol:protocol]];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    SEL selector = anInvocation.selector;
    
    for (RACEventTrampoline *trampoline in trampolines) {
        [trampoline didGetDelegateEvent:selector sender:delegator];
    }
    
    if ([actualDelegate respondsToSelector:selector]) {
        [anInvocation invokeWithTarget:actualDelegate];
    }
}

- (void)addTrampoline:(RACEventTrampoline *)trampoline {
    [trampoline setProxy:self];
    [trampolines addObject:trampoline];
}

- (BOOL)trampolinesRespondToSelector:(SEL)aSelector {
    for (RACEventTrampoline *trampoline in trampolines) {
        if (trampoline.delegateMethod == aSelector) {
            return YES;
        }
    }
    
    return NO;
}

@end
