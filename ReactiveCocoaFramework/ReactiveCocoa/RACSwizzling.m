//
//  RACSwizzling.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSwizzling.h"
#import <objc/runtime.h>


void RACSwizzle(Class class, SEL originalSelector, SEL newSelector) {
    Method origMethod = class_getInstanceMethod(class, originalSelector);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    if(class_addMethod(class, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(class, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
		method_exchangeImplementations(origMethod, newMethod);
	}
}
