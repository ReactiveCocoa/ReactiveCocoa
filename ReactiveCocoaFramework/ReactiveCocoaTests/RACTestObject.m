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
	self.hasInvokedSetObjectValueAndIntegerValue = YES;
	self.objectValue = objectValue;
	self.integerValue = integerValue;
}

- (NSString *)combineObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue {
	return [NSString stringWithFormat:@"%@: %ld", objectValue, (long)integerValue];
}

@end
