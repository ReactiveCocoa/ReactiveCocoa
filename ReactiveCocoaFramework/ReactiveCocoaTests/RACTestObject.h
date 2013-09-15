//
//  RACTestObject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
	long long integerField;
	double doubleField;
} RACTestStruct;

typedef struct {
	int field1;
	int field2;
} RACTestSmallStruct;

typedef struct {
	RACTestStruct struct1;
	RACTestStruct struct2;
} RACTestBigStruct;

typedef struct {
	float real;
	float imag;
} RACTestComplexFloatStruct;

typedef struct {
	double real;
	double imag;
} RACTestComplexDoubleStruct;

typedef float RACTestFloat4D __attribute__ ((ext_vector_type(4)));
typedef double RACTestDouble4D __attribute__ ((ext_vector_type(4)));

@interface RACTestObject : NSObject

@property (nonatomic, strong) id objectValue;
@property (nonatomic, strong) id secondObjectValue;
@property (nonatomic, strong) RACTestObject *strongTestObjectValue;
@property (nonatomic, weak) RACTestObject *weakTestObjectValue;
@property (nonatomic, assign) NSInteger integerValue;
// Holds a copy of the string.
@property (nonatomic, assign) char *charPointerValue;
// Holds a copy of the string.
@property (nonatomic, assign) const char *constCharPointerValue;
@property (nonatomic, assign) CGRect rectValue;
@property (nonatomic, assign) CGSize sizeValue;
@property (nonatomic, assign) CGPoint pointValue;
@property (nonatomic, assign) NSRange rangeValue;
@property (nonatomic, assign) RACTestStruct structValue;
@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, copy) NSArray *arrayValue;
@property (nonatomic, copy) NSSet *setValue;
@property (nonatomic, copy) NSOrderedSet *orderedSetValue;

// Returns a new object each time, with the integerValue set to 42.
@property (nonatomic, copy, readonly) RACTestObject *dynamicObjectProperty;

// Returns a new object each time, with the integerValue set to 42.
- (RACTestObject *)dynamicObjectMethod;

// Whether to allow -setNilValueForKey: to be invoked without throwing an
// exception.
@property (nonatomic, assign) BOOL catchSetNilValueForKey;

// Has -setObjectValue:andIntegerValue: been called?
@property (nonatomic, assign) BOOL hasInvokedSetObjectValueAndIntegerValue;

// Has -setObjectValue:andSecondObjectValue: been called?
@property (nonatomic, assign) BOOL hasInvokedSetObjectValueAndSecondObjectValue;

- (void)setObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue;
- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue;

// Returns a string of the form "objectValue: integerValue".
- (NSString *)combineObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue;
- (NSString *)combineObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue;

- (void)lifeIsGood:(id)sender;

+ (void)lifeIsGood:(id)sender;

- (NSRange)returnRangeValueWithObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue;

// Writes 5 to the int pointed to by intPointer.
- (void)write5ToIntPointer:(int *)intPointer;

- (NSInteger)doubleInteger:(NSInteger)integer;
- (char *)doubleString:(char *)string;
- (const char *)doubleConstString:(const char *)string;
- (RACTestStruct)doubleStruct:(RACTestStruct)testStruct;

- (RACTestSmallStruct)returnSmallStruct;
- (RACTestBigStruct)returnBigStruct;
- (RACTestComplexFloatStruct)returnComplexFloatStruct;
- (RACTestComplexDoubleStruct)returnComplexDoubleStruct;

- (_Complex float)returnComplexFloat;
- (_Complex double)returnComplexDouble;

- (RACTestFloat4D)returnFloatVector;
- (RACTestDouble4D)returnDoubleVector;

- (long double)returnLongDouble;

@end
