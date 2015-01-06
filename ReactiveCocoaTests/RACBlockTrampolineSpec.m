//
//  RACBlockTrampolineSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACBlockTrampoline.h"
#import "RACTuple.h"

QuickSpecBegin(RACBlockTrampolineSpec)

qck_it(@"should invoke the block with the given arguments", ^{
	__block NSString *stringArg;
	__block NSNumber *numberArg;
	id (^block)(NSString *, NSNumber *) = ^ id (NSString *string, NSNumber *number) {
		stringArg = string;
		numberArg = number;
		return nil;
	};

	[RACBlockTrampoline invokeBlock:block withArguments:RACTuplePack(@"hi", @1)];
	expect(stringArg).to(equal(@"hi"));
	expect(numberArg).to(equal(@1));
});

qck_it(@"should return the result of the block invocation", ^{
	NSString * (^block)(NSString *) = ^(NSString *string) {
		return string.uppercaseString;
	};

	NSString *result = [RACBlockTrampoline invokeBlock:block withArguments:RACTuplePack(@"hi")];
	expect(result).to(equal(@"HI"));
});

qck_it(@"should pass RACTupleNils as nil", ^{
	__block id arg;
	id (^block)(id) = ^ id (id obj) {
		arg = obj;
		return nil;
	};

	[RACBlockTrampoline invokeBlock:block withArguments:RACTuplePack(nil)];
	expect(arg).to(beNil());
});

QuickSpecEnd
