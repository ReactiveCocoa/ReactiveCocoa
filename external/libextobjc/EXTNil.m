//
//  EXTNil.m
//  extobjc
//
//  Created by Justin Spahr-Summers on 2011-04-25.
//  Released into the public domain.
//

#import "EXTNil.h"
#import "EXTRuntimeExtensions.h"

static id singleton = nil;

@implementation EXTNil
+ (void)initialize {
    if (self == [EXTNil class]) {
        if (!singleton)
            singleton = [self alloc];
    }
}

+ (EXTNil *)null {
    return singleton;
}

- (id)init {
    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

#pragma mark Forwarding machinery

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSUInteger returnLength = [[anInvocation methodSignature] methodReturnLength];
    if (!returnLength) {
        // nothing to do
        return;
    }

    // set return value to all zero bits
    char buffer[returnLength];
    memset(buffer, 0, returnLength);

    [anInvocation setReturnValue:buffer];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return ext_globalMethodSignatureForSelector(selector);
}

- (BOOL)respondsToSelector:(SEL)selector {
    // behave like nil
    return NO;
}

#pragma mark NSObject protocol

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return NO;
}

- (NSUInteger)hash {
    return 0;
}

- (BOOL)isEqual:(id)obj {
    return !obj || obj == self || [obj isEqual:[NSNull null]];
}

- (BOOL)isKindOfClass:(Class)class {
    return [class isEqual:[EXTNil class]] || [class isEqual:[NSNull class]];
}

- (BOOL)isMemberOfClass:(Class)class {
    return [class isEqual:[EXTNil class]] || [class isEqual:[NSNull class]];
}

- (BOOL)isProxy {
    // not really a proxy -- we just inherit from NSProxy because it makes
    // method signature lookup simpler
    return NO;
}

@end
