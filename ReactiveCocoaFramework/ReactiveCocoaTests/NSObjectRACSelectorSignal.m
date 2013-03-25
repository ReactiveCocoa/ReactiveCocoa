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

describe(@"with an instance method", ^{
	it(@"should send the argument for each invocation", ^{
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
#ifndef NS_BLOCK_ASSERTIONS
		expect(^{
			[object rac_signalForSelector:@selector(lifeIsGood:)];
		}).to.raiseAny();
#else
		__block id value;
		[[object rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
		}];

		[object lifeIsGood:@42];

		expect(value).to.beNil();
#endif
	});
});

describe(@"with a class method", ^{
	it(@"should send the argument for each invocation", ^{
		__block id value;
		[[RACSubclassObject rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
		}];

		[RACSubclassObject lifeIsGood:@42];

		expect(value).to.equal(@42);
	});

	it(@"shouldn't swizzle an existing method", ^{
#ifndef NS_BLOCK_ASSERTIONS
		expect(^{
			[RACTestObject rac_signalForSelector:@selector(lifeIsGood:)];
		}).to.raiseAny();
#else
		__block id value;
		[[RACTestObject rac_signalForSelector:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
		}];

		[RACTestObject lifeIsGood:@42];

		expect(value).to.beNil();
#endif
	});
});

SpecEnd
