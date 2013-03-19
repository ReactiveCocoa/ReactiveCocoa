//
//  NSObjectRACSelectorSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"
#import "RACSubclassObject.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACSignal.h"

SpecBegin(NSObjectRACSelectorSignal)

it(@"should send the receiver for each invocation", ^{
	RACSubclassObject *object = [[RACSubclassObject alloc] init];
	__block id value;
	[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(id x) {
		value = x;
	}];

	[object lifeIsGood:@42];

	expect(value).to.equal(@42);
});

it(@"shouldn't swizzle an existing method", ^{
	RACTestObject *object = [[RACTestObject alloc] init];
	expect(^{
		[object rac_signalForSelector:@selector(lifeIsGood:)];
	}).to.raiseAny();
});

SpecEnd
