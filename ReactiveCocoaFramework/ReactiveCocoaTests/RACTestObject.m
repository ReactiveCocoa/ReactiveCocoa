//
//  RACTestObject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"

@implementation RACTestObject

- (void)setNilValueForKey:(NSString *)key {
	[self setValue:@0 forKey:key];
}

- (void)setObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue {
	self.objectValue = objectValue;
	self.integerValue = integerValue;
}

@end
