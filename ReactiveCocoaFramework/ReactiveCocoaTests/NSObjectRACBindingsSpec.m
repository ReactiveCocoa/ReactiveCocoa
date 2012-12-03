//
//  NSObjectRACBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 03/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

@interface TestClass : NSObject
@property (nonatomic, strong) NSString *name;
@end

@implementation TestClass
@end

SpecBegin(NSObjectRACBindings)

describe(@"two-way bindings", ^{
	
});

SpecEnd