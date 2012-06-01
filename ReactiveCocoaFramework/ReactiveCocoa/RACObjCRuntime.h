//
//  RACObjCRuntime.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface RACObjCRuntime : NSObject

+ (void)findMethod:(SEL)method inProtocol:(Protocol *)protocol outMethod:(struct objc_method_description *)outMethod;
+ (const char *)getMethodTypesForMethod:(SEL)method inProtocol:(Protocol *)protocol;
+ (BOOL)method:(SEL)method existsInProtocol:(Protocol *)protocol;

@end
