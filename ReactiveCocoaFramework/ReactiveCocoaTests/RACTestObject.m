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

- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue {
	self.hasInvokedSetObjectValueAndSecondObjectValue = YES;
	self.objectValue = objectValue;
	self.secondObjectValue = secondObjectValue;
}

- (NSString *)combineObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue {
	return [NSString stringWithFormat:@"%@: %ld", objectValue, (long)integerValue];
}

- (NSString *)combineObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue {
	return [NSString stringWithFormat:@"%@: %@", objectValue, secondObjectValue];
}

- (void)lifeIsGood:(id)sender {
	
}

+ (void)lifeIsGood:(id)sender {
	
}

- (NSRange)returnRangeValueWithObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue {
	return NSMakeRange((NSUInteger)[objectValue integerValue], (NSUInteger)integerValue);
}

@end
