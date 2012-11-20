//
//  NSInvocation+RACTypeParsing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSInvocation+RACTypeParsing.h"
#import "RACUnit.h"

@implementation NSInvocation (RACTypeParsing)

- (void)rac_setArgument:(id)object atIndex:(NSUInteger)index {
#define PULL_AND_SET(type, selector) \
	do { \
		type val = [object selector]; \
		[self setArgument:&val atIndex:(NSInteger)index]; \
	} while(0)

	const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
	if (strcmp(argType, "@") == 0 || strcmp(argType, "#") == 0) {
		[self setArgument:&object atIndex:(NSInteger)index];
	} else if (strcmp(argType, "c") == 0) {
		PULL_AND_SET(char, charValue);
	} else if (strcmp(argType, "i") == 0) {
		PULL_AND_SET(int, intValue);
	} else if (strcmp(argType, "s") == 0) {
		PULL_AND_SET(short, shortValue);
	} else if (strcmp(argType, "l") == 0) {
		PULL_AND_SET(long, longValue);
	} else if (strcmp(argType, "q") == 0) {
		PULL_AND_SET(long long, longLongValue);
	} else if (strcmp(argType, "C") == 0) {
		PULL_AND_SET(unsigned char, unsignedCharValue);
	} else if (strcmp(argType, "I") == 0) {
		PULL_AND_SET(unsigned int, unsignedIntValue);
	} else if (strcmp(argType, "C") == 0) {
		PULL_AND_SET(unsigned short, unsignedShortValue);
	} else if (strcmp(argType, "L") == 0) {
		PULL_AND_SET(unsigned long, unsignedLongValue);
	} else if (strcmp(argType, "Q") == 0) {
		PULL_AND_SET(unsigned long long, unsignedLongLongValue);
	} else if (strcmp(argType, "f") == 0) {
		PULL_AND_SET(float, floatValue);
	} else if (strcmp(argType, "d") == 0) {
		PULL_AND_SET(double, doubleValue);
	} else if (strcmp(argType, "*") == 0) {
		PULL_AND_SET(const char *, UTF8String);
	} else if (argType[0] == '^') {
		PULL_AND_SET(void *, pointerValue);
	} else {
		NSAssert(NO, @"Unknown argument type %s", argType);
	}

#undef PULL_AND_SET
}

- (id)rac_returnValue {
#define WRAP_AND_RETURN(type) \
	type val = 0; \
	[self getReturnValue:&val]; \
	return @(val);

	const char *typeSignature = self.methodSignature.methodReturnType;
	if (strcmp(typeSignature, "@") == 0 || strcmp(typeSignature, "#") == 0) {
		__autoreleasing id returnObj;
		[self getReturnValue:&returnObj];
		return returnObj;
	} else if (strcmp(typeSignature, "c") == 0) {
		WRAP_AND_RETURN(char);
	} else if (strcmp(typeSignature, "i") == 0) {
		WRAP_AND_RETURN(int);
	} else if (strcmp(typeSignature, "s") == 0) {
		WRAP_AND_RETURN(short);
	} else if (strcmp(typeSignature, "l") == 0) {
		WRAP_AND_RETURN(long);
	} else if (strcmp(typeSignature, "q") == 0) {
		WRAP_AND_RETURN(long long);
	} else if (strcmp(typeSignature, "C") == 0) {
		WRAP_AND_RETURN(unsigned char);
	} else if (strcmp(typeSignature, "I") == 0) {
		WRAP_AND_RETURN(unsigned int);
	} else if (strcmp(typeSignature, "C") == 0) {
		WRAP_AND_RETURN(unsigned short);
	} else if (strcmp(typeSignature, "L") == 0) {
		WRAP_AND_RETURN(unsigned long);
	} else if (strcmp(typeSignature, "Q") == 0) {
		WRAP_AND_RETURN(unsigned long long);
	} else if (strcmp(typeSignature, "f") == 0) {
		WRAP_AND_RETURN(float);
	} else if (strcmp(typeSignature, "d") == 0) {
		WRAP_AND_RETURN(double);
	} else if (strcmp(typeSignature, "*") == 0) {
		WRAP_AND_RETURN(const char *);
	} else if (strcmp(typeSignature, "v") == 0) {
		return RACUnit.defaultUnit;
	} else if (typeSignature[0] == '^') {
		const void *pointer = NULL;
		[self getReturnValue:&pointer];
		return [NSValue valueWithPointer:pointer];
	} else {
		NSAssert(NO, @"Unknown return type signature %s", typeSignature);
	}

	return nil;

#undef WRAP_AND_RETURN
}

@end
