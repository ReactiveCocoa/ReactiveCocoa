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
#import "RACUnit.h"

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

	it(@"should swizzle an existing method", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelectorInvocation:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
		}];

		[object lifeIsGood:@42];

		expect(value).to.equal(@42);
	});
	
	it(@"shouldn't swizzle a none existing method", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
#ifndef NS_BLOCK_ASSERTIONS
		expect(^{
			[object rac_signalForSelectorInvocation:@selector(subscribe:)];
		}).to.raiseAny();
#else
		__block id value;
		[[object rac_signalForSelectorInvocation:@selector(subscribe:)] subscribeNext:^(id x) {
			value = x;
		}];

		[object lifeIsGood:@42];

		expect(value).to.beNil();
#endif
	});

	it(@"should swizzle an existing method only once", ^{
		RACSubclassObject *object = [[RACSubclassObject alloc] init];
		RACSubclassObject *object2 = [[RACSubclassObject alloc] init];
		RACSubclassObject *object3 = [[RACSubclassObject alloc] init];
		RACSubclassObject *object4 = [[RACSubclassObject alloc] init];
		__block id value;
		__block int callCount = 0;
		[[object rac_signalForSelectorInvocation:@selector(setObjectValue:)] subscribeNext:^(id x) {
			value = x;
			callCount++;
		}];
		[[object2 rac_signalForSelectorInvocation:@selector(setObjectValue:)] subscribeNext:^(id x) {
			value = x;
			callCount++;
		}];
		[[object3 rac_signalForSelectorInvocation:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
			callCount++;
		}];
		[[object4 rac_signalForSelectorInvocation:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
			callCount++;
		}];

		object.objectValue = @42;

		expect(value).to.equal(@42);
		expect(object.objectValue).to.equal(@42);

		object2.objectValue = @31;

		expect(value).to.equal(@31);
		expect(object2.objectValue).to.equal(@31);

		[object3 lifeIsGood:@20];

		expect(value).to.equal(@20);

		[object4 lifeIsGood:@10];

		expect(value).to.equal(@10);

		expect(callCount).to.equal(4);
	});

	it(@"should work for integer", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelectorInvocation:@selector(setIntegerValue:)] subscribeNext:^(id x) {
			value = x;
		}];

		object.integerValue = 42;

		expect(value).to.equal(@42);
		expect(object.integerValue).to.equal(42);
	});

	it(@"should work for char pointer", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelectorInvocation:@selector(setConstCharPointerValue:)] subscribeNext:^(id x) {
			value = x;
		}];

		const char *string = "blah blah blah";
		object.constCharPointerValue = string;

		expect(value).to.equal(@"blah blah blah");
		expect(strcmp(object.constCharPointerValue, string) == 0).to.beTruthy();
	});

	it(@"should work for CGRect", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelectorInvocation:@selector(setRectValue:)] subscribeNext:^(id x) {
			value = x;
		}];

		CGRect rect = CGRectMake(10, 20, 30, 40);
		object.rectValue = rect;

		expect([value rectValue]).to.equal(rect);
		expect(object.rectValue).to.equal(rect);
	});

	it(@"should work for void", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		__block id value;
		[[object rac_signalForSelectorInvocation:@selector(lifeIsGood)] subscribeNext:^(id x) {
			value = x;
		}];

		[object lifeIsGood];

		expect(value).to.equal(RACUnit.defaultUnit);
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

	it(@"should swizzle an existing method", ^{
		__block id value;
		[[RACTestObject rac_signalForSelectorInvocation:@selector(lifeIsGood:)] subscribeNext:^(id x) {
			value = x;
		}];

		[RACTestObject lifeIsGood:@42];

		expect(value).to.equal(@42);
	});

	it(@"shouldn't swizzle a none existing method", ^{
#ifndef NS_BLOCK_ASSERTIONS
		expect(^{
			[RACTestObject rac_signalForSelectorInvocation:@selector(subscribe:)];
		}).to.raiseAny();
#else
		__block id value;
		[[RACTestObject rac_signalForSelectorInvocation:@selector(subscribe:)] subscribeNext:^(id x) {
			value = x;
		}];

		[RACTestObject lifeIsGood:@42];

		expect(value).to.beNil();
#endif
	});
});

SpecEnd
