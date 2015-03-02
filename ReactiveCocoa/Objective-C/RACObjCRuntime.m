//
//  RACObjCRuntime.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/19/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACObjCRuntime.h"
#import <objc/runtime.h>

#if __has_feature(objc_arc)
#error "This file must be compiled without ARC."
#endif

@implementation RACObjCRuntime

+ (Class)createClass:(const char *)className inheritingFromClass:(Class)superclass {
	return objc_allocateClassPair(superclass, className, 0);
}

@end
