//
//  NSInvocation+RACTypeParsing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSInvocation+RACTypeParsing.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation NSInvocation (RACTypeParsing)

- (void)rac_setArgument:(id)object atIndex:(NSUInteger)index {
#define PULL_AND_SET(type, selector) \
	do { \
		type val = [object selector]; \
		[self setArgument:&val atIndex:(NSInteger)index]; \
	} while(0)

	const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
	// Skip const type qualifier.
	if (argType[0] == 'r') {
		argType++;
	}

	if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
		[self setArgument:&object atIndex:(NSInteger)index];
	} else if (strcmp(argType, @encode(char)) == 0) {
		PULL_AND_SET(char, charValue);
	} else if (strcmp(argType, @encode(int)) == 0) {
		PULL_AND_SET(int, intValue);
	} else if (strcmp(argType, @encode(short)) == 0) {
		PULL_AND_SET(short, shortValue);
	} else if (strcmp(argType, @encode(long)) == 0) {
		PULL_AND_SET(long, longValue);
	} else if (strcmp(argType, @encode(long long)) == 0) {
		PULL_AND_SET(long long, longLongValue);
	} else if (strcmp(argType, @encode(unsigned char)) == 0) {
		PULL_AND_SET(unsigned char, unsignedCharValue);
	} else if (strcmp(argType, @encode(unsigned int)) == 0) {
		PULL_AND_SET(unsigned int, unsignedIntValue);
	} else if (strcmp(argType, @encode(unsigned short)) == 0) {
		PULL_AND_SET(unsigned short, unsignedShortValue);
	} else if (strcmp(argType, @encode(unsigned long)) == 0) {
		PULL_AND_SET(unsigned long, unsignedLongValue);
	} else if (strcmp(argType, @encode(unsigned long long)) == 0) {
		PULL_AND_SET(unsigned long long, unsignedLongLongValue);
	} else if (strcmp(argType, @encode(float)) == 0) {
		PULL_AND_SET(float, floatValue);
	} else if (strcmp(argType, @encode(double)) == 0) {
		PULL_AND_SET(double, doubleValue);
	} else if (strcmp(argType, @encode(BOOL)) == 0) {
		PULL_AND_SET(BOOL, boolValue);
	} else if (strcmp(argType, @encode(char *)) == 0) {
		const char *cString = [object UTF8String];
		[self setArgument:&cString atIndex:(NSInteger)index];
		[self retainArguments];
	} else if (strcmp(argType, @encode(void (^)(void))) == 0) {
		[self setArgument:&object atIndex:(NSInteger)index];
	} else {
		NSCParameterAssert([object isKindOfClass:NSValue.class]);

		NSUInteger valueSize = 0;
		NSGetSizeAndAlignment([object objCType], &valueSize, NULL);

#if DEBUG
		NSUInteger argSize = 0;
		NSGetSizeAndAlignment(argType, &argSize, NULL);
		NSCAssert(valueSize == argSize, @"Value size does not match argument size in -rac_setArgument: %@ atIndex: %lu", object, (unsigned long)index);
#endif
		
		unsigned char valueBytes[valueSize];
		[object getValue:valueBytes];

		[self setArgument:valueBytes atIndex:(NSInteger)index];
	}

#undef PULL_AND_SET
}

- (id)rac_argumentAtIndex:(NSUInteger)index {
#define WRAP_AND_RETURN(type) \
	do { \
		type val = 0; \
		[self getArgument:&val atIndex:(NSInteger)index]; \
		return @(val); \
	} while (0)

	const char *argType = [self.methodSignature getArgumentTypeAtIndex:index];
	// Skip const type qualifier.
	if (argType[0] == 'r') {
		argType++;
	}

	if (strcmp(argType, @encode(id)) == 0 || strcmp(argType, @encode(Class)) == 0) {
		__autoreleasing id returnObj;
		[self getArgument:&returnObj atIndex:(NSInteger)index];
		return returnObj;
	} else if (strcmp(argType, @encode(char)) == 0) {
		WRAP_AND_RETURN(char);
	} else if (strcmp(argType, @encode(int)) == 0) {
		WRAP_AND_RETURN(int);
	} else if (strcmp(argType, @encode(short)) == 0) {
		WRAP_AND_RETURN(short);
	} else if (strcmp(argType, @encode(long)) == 0) {
		WRAP_AND_RETURN(long);
	} else if (strcmp(argType, @encode(long long)) == 0) {
		WRAP_AND_RETURN(long long);
	} else if (strcmp(argType, @encode(unsigned char)) == 0) {
		WRAP_AND_RETURN(unsigned char);
	} else if (strcmp(argType, @encode(unsigned int)) == 0) {
		WRAP_AND_RETURN(unsigned int);
	} else if (strcmp(argType, @encode(unsigned short)) == 0) {
		WRAP_AND_RETURN(unsigned short);
	} else if (strcmp(argType, @encode(unsigned long)) == 0) {
		WRAP_AND_RETURN(unsigned long);
	} else if (strcmp(argType, @encode(unsigned long long)) == 0) {
		WRAP_AND_RETURN(unsigned long long);
	} else if (strcmp(argType, @encode(float)) == 0) {
		WRAP_AND_RETURN(float);
	} else if (strcmp(argType, @encode(double)) == 0) {
		WRAP_AND_RETURN(double);
	} else if (strcmp(argType, @encode(BOOL)) == 0) {
		WRAP_AND_RETURN(BOOL);
	} else if (strcmp(argType, @encode(char *)) == 0) {
		WRAP_AND_RETURN(const char *);
	} else if (strcmp(argType, @encode(void (^)(void))) == 0) {
		__unsafe_unretained id block = nil;
		[self getArgument:&block atIndex:(NSInteger)index];
		return [block copy];
	} else {
		NSUInteger valueSize = 0;
		NSGetSizeAndAlignment(argType, &valueSize, NULL);

		unsigned char valueBytes[valueSize];
		[self getArgument:valueBytes atIndex:(NSInteger)index];
		
		return [NSValue valueWithBytes:valueBytes objCType:argType];
	}

	return nil;

#undef WRAP_AND_RETURN
}

- (RACTuple *)rac_argumentsTuple {
	NSUInteger numberOfArguments = self.methodSignature.numberOfArguments;
	NSMutableArray *argumentsArray = [NSMutableArray arrayWithCapacity:numberOfArguments - 2];
	for (NSUInteger index = 2; index < numberOfArguments; index++) {
		[argumentsArray addObject:[self rac_argumentAtIndex:index] ?: RACTupleNil.tupleNil];
	}

	return [RACTuple tupleWithObjectsFromArray:argumentsArray];
}

- (void)setRac_argumentsTuple:(RACTuple *)arguments {
	NSCAssert(arguments.count == self.methodSignature.numberOfArguments - 2, @"Number of supplied arguments (%lu), does not match the number expected by the signature (%lu)", (unsigned long)arguments.count, (unsigned long)self.methodSignature.numberOfArguments - 2);

	NSUInteger index = 2;
	for (id arg in arguments) {
		[self rac_setArgument:(arg == RACTupleNil.tupleNil ? nil : arg) atIndex:index];
		index++;
	}
}

- (id)rac_returnValue {
#define WRAP_AND_RETURN(type) \
	do { \
		type val = 0; \
		[self getReturnValue:&val]; \
		return @(val); \
	} while (0)

	const char *returnType = self.methodSignature.methodReturnType;
	// Skip const type qualifier.
	if (returnType[0] == 'r') {
		returnType++;
	}

	if (strcmp(returnType, @encode(id)) == 0 || strcmp(returnType, @encode(Class)) == 0 || strcmp(returnType, @encode(void (^)(void))) == 0) {
		__autoreleasing id returnObj;
		[self getReturnValue:&returnObj];
		return returnObj;
	} else if (strcmp(returnType, @encode(char)) == 0) {
		WRAP_AND_RETURN(char);
	} else if (strcmp(returnType, @encode(int)) == 0) {
		WRAP_AND_RETURN(int);
	} else if (strcmp(returnType, @encode(short)) == 0) {
		WRAP_AND_RETURN(short);
	} else if (strcmp(returnType, @encode(long)) == 0) {
		WRAP_AND_RETURN(long);
	} else if (strcmp(returnType, @encode(long long)) == 0) {
		WRAP_AND_RETURN(long long);
	} else if (strcmp(returnType, @encode(unsigned char)) == 0) {
		WRAP_AND_RETURN(unsigned char);
	} else if (strcmp(returnType, @encode(unsigned int)) == 0) {
		WRAP_AND_RETURN(unsigned int);
	} else if (strcmp(returnType, @encode(unsigned short)) == 0) {
		WRAP_AND_RETURN(unsigned short);
	} else if (strcmp(returnType, @encode(unsigned long)) == 0) {
		WRAP_AND_RETURN(unsigned long);
	} else if (strcmp(returnType, @encode(unsigned long long)) == 0) {
		WRAP_AND_RETURN(unsigned long long);
	} else if (strcmp(returnType, @encode(float)) == 0) {
		WRAP_AND_RETURN(float);
	} else if (strcmp(returnType, @encode(double)) == 0) {
		WRAP_AND_RETURN(double);
	} else if (strcmp(returnType, @encode(BOOL)) == 0) {
		WRAP_AND_RETURN(BOOL);
	} else if (strcmp(returnType, @encode(char *)) == 0) {
		WRAP_AND_RETURN(const char *);
	} else if (strcmp(returnType, @encode(void)) == 0) {
		return RACUnit.defaultUnit;
	} else {
		NSUInteger valueSize = 0;
		NSGetSizeAndAlignment(returnType, &valueSize, NULL);

		unsigned char valueBytes[valueSize];
		[self getReturnValue:valueBytes];

		return [NSValue valueWithBytes:valueBytes objCType:returnType];
	}

	return nil;

#undef WRAP_AND_RETURN
}

@end
