//
//  RACSamplingSignalGeneratorSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-27.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSamplingSignalGenerator.h"

#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACTuple.h"

SpecBegin(RACSamplingSignalGenerator)

__block RACSubject *sampledSubject;

__block RACSamplingSignalGenerator *generator;
__block NSUInteger generationCount;
__block NSUInteger subscriptionCount;

beforeEach(^{
	sampledSubject = [RACSubject subject];
	generator = [RACSamplingSignalGenerator
		generatorBySampling:sampledSubject forGenerator:[RACDynamicSignalGenerator generatorWithBlock:^(RACTuple *xs) {
			generationCount++;

			return [RACSignal defer:^{
				subscriptionCount++;
				return [RACSignal return:xs];
			}];
		}]];
	
	expect(generator).notTo.beNil();

	generationCount = 0;
	subscriptionCount = 0;
});

it(@"should not invoke the generator before an event is sampled", ^{
	RACSignal *signal = [generator signalWithValue:nil];
	expect(signal).notTo.beNil();

	[signal subscribe:nil];
	expect(generationCount).to.equal(0);
});

it(@"should pass through generated events after an event is sampled", ^{
	RACSignal *signal = [generator signalWithValue:@"foo"];
	expect(signal).notTo.beNil();

	__block RACTuple *tuple = nil;
	__block BOOL completed = NO;
	[signal subscribeNext:^(RACTuple *t) {
		tuple = t;
	} completed:^{
		completed = YES;
	}];

	expect(generationCount).to.equal(0);

	[sampledSubject sendNext:@"bar"];

	expect(tuple).to.equal(RACTuplePack(@"foo", @"bar"));
	expect(completed).to.beTruthy();
	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(1);
});

it(@"should error if the sampled signal errors", ^{
	NSError *testError = [NSError errorWithDomain:@"foobar" code:123 userInfo:nil];
	RACSignal *signal = [generator signalWithValue:nil];

	__block NSError *error = nil;
	[signal subscribeError:^(NSError *e) {
		error = e;
	}];

	[sampledSubject sendError:testError];

	expect(error).to.equal(testError);
	expect(generationCount).to.equal(0);
	expect(subscriptionCount).to.equal(0);
});

it(@"should complete if the sampled signal completes", ^{
	RACSignal *signal = [generator signalWithValue:nil];

	__block BOOL completed;
	[signal subscribeCompleted:^{
		completed = YES;
	}];

	[sampledSubject sendCompleted];

	expect(completed).to.beTruthy();
	expect(generationCount).to.equal(0);
	expect(subscriptionCount).to.equal(0);
});

it(@"should use the last sampled value upon subscription", ^{
	[sampledSubject sendNext:@"bar"];
	[sampledSubject sendNext:@"buzz"];

	RACSignal *signal = [generator signalWithValue:@"foo"];
	expect(signal).notTo.beNil();
	expect(generationCount).to.equal(0);

	expect([signal first]).to.equal(RACTuplePack(@"foo", @"buzz"));
	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(1);
});

it(@"should forward a terminating event upon subscription", ^{
	[sampledSubject sendCompleted];

	RACSignal *signal = [generator signalWithValue:nil];
	expect(signal).notTo.beNil();
	expect(generationCount).to.equal(0);

	expect([signal waitUntilCompleted:NULL]).to.beTruthy();
	expect(generationCount).to.equal(0);
	expect(subscriptionCount).to.equal(0);
});

SpecEnd
