//
//  RACObjCRuntime.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACObjCRuntime.h"

@implementation RACObjCRuntime

+ (void)findMethod:(SEL)method inProtocol:(Protocol *)protocol outMethod:(struct objc_method_description *)outMethod {
    *outMethod = protocol_getMethodDescription(protocol, method, NO, YES);
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

//unsigned int protoCount;
//Protocol *__unsafe_unretained *protoList = protocol_copyProtocolList(proto, &protoCount);
//
//for (int i = 0; i < protoCount; i++) {
//    unsigned int methodCount;
//    struct objc_method_description* methods = protocol_copyMethodDescriptionList(protoList[i], NO, YES, &methodCount);
//    
//    for (int j = 0; j < methodCount; j++) {
//        struct objc_method_description d = methods[i];
//        if (d.name == aSelector) {
//            free(methods);
//            free(protoList);
//            return YES;
//        }
//    }
//    
//    free(methods);
//}
//
//free(protoList);

@end
