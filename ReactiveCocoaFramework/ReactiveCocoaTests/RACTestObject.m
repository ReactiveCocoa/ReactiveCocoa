//
//  RACTestObject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"

@implementation RACTestObject

- (void)dealloc {
	free(_charPointerValue);
	free((void *)_constCharPointerValue);
}

- (void)setNilValueForKey:(NSString *)key {
	if (!self.catchSetNilValueForKey) [super setNilValueForKey:key];
}

- (void)setCharPointerValue:(char *)charPointerValue {
	if (charPointerValue == _charPointerValue) return;
	free(_charPointerValue);
	_charPointerValue = strdup(charPointerValue);
}

- (void)setConstCharPointerValue:(const char *)constCharPointerValue {
	if (constCharPointerValue == _constCharPointerValue) return;
	free((void *)_constCharPointerValue);
	_constCharPointerValue = strdup(constCharPointerValue);
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

- (void)write5ToIntPointer:(int *)intPointer {
	NSCParameterAssert(intPointer != NULL);
	*intPointer = 5;
}

- (NSInteger)doubleInteger:(NSInteger)integer {
	return integer * 2;
}

- (char *)doubleString:(char *)string {
	size_t doubledSize = strlen(string) * 2 + 1;
	char *doubledString = malloc(sizeof(char) * doubledSize);

	// Create an autoreleasing NSData to free the buffer eventually
	__autoreleasing NSData *data __attribute__((unused)) = [NSData dataWithBytesNoCopy:doubledString length:doubledSize freeWhenDone:YES];

	doubledString[0] = '\0';
	strlcat(doubledString, string, doubledSize);
	strlcat(doubledString, string, doubledSize);

	return doubledString;
}

- (const char *)doubleConstString:(const char *)string {
	return [self doubleString:(char *)string];
}

- (RACTestStruct)doubleStruct:(RACTestStruct)testStruct {
	testStruct.integerField *= 2;
	testStruct.doubleField *= 2;
	return testStruct;
}

@end
