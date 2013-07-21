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
	if (!self.catchSetNilValueForKey) [super setNilValueForKey:key];
}

- (void)setCharPointerValue:(char *)charPointerValue {
	free(_charPointerValue);
	size_t length = strlen(charPointerValue);
	_charPointerValue = malloc(length+1);
	strlcpy(_charPointerValue, charPointerValue, length+1);
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

- (RACTestObject *)dynamicObjectProperty {
	return [self dynamicObjectMethod];
}

- (RACTestObject *)dynamicObjectMethod {
	RACTestObject *testObject = [[RACTestObject alloc] init];
	testObject.integerValue = 42;
	return testObject;
}

@end
