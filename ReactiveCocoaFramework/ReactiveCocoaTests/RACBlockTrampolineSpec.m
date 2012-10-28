//
//  RACBlockTrampolineSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACBlockTrampoline.h"

SpecBegin(RACBlockTrampoline)

it(@"should invoke the block with the given arguments", ^{
	__block NSString *stringArg;
	__block NSNumber *numberArg;
	id (^block)(NSString *, NSNumber *) = ^ id (NSString *string, NSNumber *number) {
		stringArg = string;
		numberArg = number;
		return nil;
	};

	[RACBlockTrampoline invokeBlock:block withArguments:@[ @"hi", @1 ]];
	expect(stringArg).to.equal(@"hi");
	expect(numberArg).to.equal(@1);
});

it(@"should return the result of the block invocation", ^{
	id (^block)(NSString *) = ^(NSString *string) {
		return string.uppercaseString;
	};

	NSString *result = [RACBlockTrampoline invokeBlock:block withArguments:@[ @"hi" ]];
	expect(result).to.equal(@"HI");
});

SpecEnd
