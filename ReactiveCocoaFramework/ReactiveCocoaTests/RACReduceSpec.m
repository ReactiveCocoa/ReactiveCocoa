//
//  RACReduceSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 4/7/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACReduce.h"

SpecBegin(RACReduce)

it(@"should invoke the block with the given arguments", ^{
	__block NSString *stringArg;
	__block NSNumber *numberArg;
	id (^block)(RACTuple *) = RACReduce(^ id (NSString *string, NSNumber *number) {
		stringArg = string;
		numberArg = number;
		return nil;
	});

	block(RACTuplePack(@"hi", @1));
	expect(stringArg).to.equal(@"hi");
	expect(numberArg).to.equal(@1);
});

it(@"should return the result of the block invocation", ^{
	NSString * (^block)(RACTuple *) = RACReduce(^(NSString *string) {
		return string.uppercaseString;
	});

	NSString *result = block(RACTuplePack(@"hi"));
	expect(result).to.equal(@"HI");
});

it(@"should return the BOOL result of the block invocation", ^{
	BOOL (^block)(RACTuple *) = RACReduce(^ BOOL (NSString *string) {
		return string.length == 0;
	});

	BOOL result = block(RACTuplePack(@"hi"));
	expect(result).to.equal(NO);
});

it(@"should pass RACTupleNils as nil", ^{
	__block id arg;
	id (^block)(RACTuple *) = RACReduce(^ id (id obj) {
		arg = obj;
		return nil;
	});

	block(RACTuplePack(nil));
	expect(arg).to.beNil();
});

SpecEnd
