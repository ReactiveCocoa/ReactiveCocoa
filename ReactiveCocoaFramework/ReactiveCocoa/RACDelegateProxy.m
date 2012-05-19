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

@implementation RACDelegateProxy

@synthesize protocol;
@synthesize delegator;
@synthesize actualDelegate;

+ (id)proxyWithProtocol:(Protocol *)protocol andDelegator:(NSObject *)delegator {
    RACDelegateProxy *proxy = [[self alloc] init];
    [proxy setProtocol:protocol];
    [proxy setDelegator:delegator];
    return proxy;
}

- (id)init {
    if (self = [super init]) {
        trampolines = [[NSMutableSet alloc] init];
    }
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([RACObjCRuntime method:aSelector existsInProtocol:protocol])
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
    } else {
        [self doesNotRecognizeSelector:selector];
    }
}

- (void)addTrampoline:(RACEventTrampoline *)trampoline {
    [trampolines addObject:trampoline];
}

@end
