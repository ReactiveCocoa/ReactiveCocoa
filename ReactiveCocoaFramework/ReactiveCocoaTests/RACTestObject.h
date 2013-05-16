//
//  RACTestObject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RACTestObject : NSObject

@property (nonatomic, strong) id objectValue;
@property (nonatomic, strong) id secondObjectValue;
@property (nonatomic, assign) NSInteger integerValue;
@property (nonatomic, assign) char *charPointerValue;
@property (nonatomic, assign) const char *constCharPointerValue;
@property (nonatomic, assign) CGRect rectValue;
@property (nonatomic, assign) CGSize sizeValue;
@property (nonatomic, assign) CGPoint pointValue;
@property (nonatomic, assign) NSRange rangeValue;

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

@end
