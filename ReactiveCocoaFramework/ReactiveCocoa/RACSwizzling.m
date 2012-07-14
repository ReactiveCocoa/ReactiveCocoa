//
//  RACSwizzling.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSwizzling.h"
#import "JRSwizzle.h"


void RACSwizzle(Class class, SEL originalSelector, SEL newSelector) {
    [class jr_swizzleMethod:originalSelector withMethod:newSelector error:NULL];
}
