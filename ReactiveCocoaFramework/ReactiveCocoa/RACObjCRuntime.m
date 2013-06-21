//
//  RACObjCRuntime.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACObjCRuntime.h"

#if __has_feature(objc_arc)
#error "This file must be compiled without ARC."
#endif

@implementation RACObjCRuntime

+ (void)findMethod:(SEL)method inProtocol:(Protocol *)protocol outMethod:(struct objc_method_description *)outMethod {
    // First, we look for a @required method. If none is found, we look for an
    // @optional method.
    *outMethod = protocol_getMethodDescription(protocol, method, YES, YES);
    if (outMethod->name == NULL) {
        *outMethod = protocol_getMethodDescription(protocol, method, NO, YES);
    }
}

+ (const char *)getMethodTypesForMethod:(SEL)method inProtocol:(Protocol *)protocol {
    struct objc_method_description desc;
    [self findMethod:method inProtocol:protocol outMethod:&desc];
    return desc.types;
}

+ (BOOL)method:(SEL)method existsInProtocol:(Protocol *)protocol {
    struct objc_method_description desc;
    [self findMethod:method inProtocol:protocol outMethod:&desc];
    return desc.name != NULL;
}

+ (Class)createClass:(const char *)className inheritingFromClass:(Class)superclass {
	return objc_allocateClassPair(superclass, className, 0);
}

@end
