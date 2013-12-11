//
//  RACAggregatingSignalGeneratorSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-10.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAggregatingSignalGenerator.h"

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACUnit.h"

SpecBegin(RACAggregatingSignalGenerator)

__block RACAggregatingSignalGenerator *generator;
__block NSUInteger generationCount;
__block NSUInteger subscriptionCount;
__block NSUInteger disposedCount;

__block NSMutableArray *generatedSignals;

beforeEach(^{
	generationCount = 0;
	subscriptionCount = 0;
	disposedCount = 0;

	generator = [[RACDynamicSignalGenerator
		generatorWithBlock:^(RACSignal *input) {
			generationCount++;

			return [RACSignal defer:^{
				subscriptionCount++;

				return [input doDisposed:^{
					disposedCount++;
				}];
			}];
		}]
		aggregate];
	
	expect(generator).notTo.beNil();

	generatedSignals = [NSMutableArray array];
	[generator.generatedSignals subscribeNext:^(RACSignal *signal) {
		[generatedSignals addObject:signal];
	}];
});

it(@"should invoke the inner generator immediately", ^{
	RACSignal *signal = [generator signalWithValue:[RACSignal empty]];
	expect(signal).notTo.beNil();

	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(0);
	expect(generatedSignals.count).to.equal(0);
});

it(@"should send on generatedSignals when subscribed to", ^{
	RACSignal *signal = [generator signalWithValue:[RACSignal return:RACUnit.defaultUnit]];

	[signal subscribe:nil];

	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(0);

	expect(generatedSignals.count).to.equal(1);
	expect([generatedSignals[0] first]).to.equal(RACUnit.defaultUnit);
	expect(subscriptionCount).to.equal(1);

	[signal subscribe:nil];

	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(1);

	expect(generatedSignals.count).to.equal(2);
	expect([generatedSignals[1] first]).to.equal(RACUnit.defaultUnit);
	expect(subscriptionCount).to.equal(2);
});

it(@"should pass through events from all of the generated signal's subscriptions", ^{
	RACSubject *terminateSubject = [RACSubject subject];

	__block NSUInteger counter = 0;
	RACSignal *counterSignal = [RACSignal defer:^{
		return [terminateSubject startWith:@(counter++)];
	}];

	NSMutableArray *values = [NSMutableArray array];
	__block BOOL completed = NO;

	[[generator
		signalWithValue:counterSignal]
		subscribeNext:^(NSNumber *x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];
	
	RACSignal *generatedSignal = generatedSignals[0];
	
	expect([generatedSignal first]).to.equal(@0);
	expect(subscriptionCount).to.equal(1);
	expect(values).to.equal((@[ @0 ]));
	expect(completed).to.beFalsy();
	
	expect([generatedSignal first]).to.equal(@1);
	expect(subscriptionCount).to.equal(2);
	expect(values).to.equal((@[ @0, @1 ]));
	expect(completed).to.beFalsy();
	
	expect([generatedSignal first]).to.equal(@2);
	expect(subscriptionCount).to.equal(3);
	expect(values).to.equal((@[ @0, @1, @2 ]));
	expect(completed).to.beFalsy();

	[generatedSignal subscribe:nil];
	expect(subscriptionCount).to.equal(4);

	[terminateSubject sendCompleted];
	expect(subscriptionCount).to.equal(4);
	expect(values).to.equal((@[ @0, @1, @2, @3 ]));
	expect(completed).to.beTruthy();
});

it(@"should dispose of the generated signal", ^{
	RACSignal *signal = [generator signalWithValue:[RACSignal never]];
	expect(signal).notTo.beNil();

	[signal subscribe:nil];

	RACDisposable *disposable = [generatedSignals[0] subscribe:nil];
	expect(disposable).notTo.beNil();
	expect(disposedCount).to.equal(0);

	[disposable dispose];
	expect(disposedCount).to.equal(1);
});

it(@"should complete generatedSignals upon deallocation", ^{
	__block BOOL deallocated = NO;
	__block BOOL completed = NO;

	@autoreleasepool {
		RACAggregatingSignalGenerator *generator __attribute__((objc_precise_lifetime)) = [[RACDynamicSignalGenerator
			generatorWithBlock:^(RACSignal *input) {
				return input;
			}]
			aggregate];
		
		[generator.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocated = YES;
		}]];

		[[generator.generatedSignals
			flatten]
			subscribeCompleted:^{
				completed = YES;
			}];

		[[generator
			signalWithValue:[RACSignal empty]]
			subscribe:nil];

		expect(deallocated).to.beFalsy();
		expect(completed).to.beFalsy();
	}

	expect(deallocated).will.beTruthy();
	expect(completed).to.beTruthy();
});

it(@"should send signals in the order they're enqueued", ^{
	const size_t count = 100;

	NSMutableArray *generatedValues = [NSMutableArray array];
	[[generator.generatedSignals
		concat]
		subscribeNext:^(NSNumber *num) {
			[generatedValues addObject:num];
		}];

	NSMutableArray *subscribedValues = [NSMutableArray array];

	dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t index) {
		RACSignal *signal = [generator signalWithValue:[RACSignal return:@(index)]];

		@synchronized (subscribedValues) {
			[signal subscribe:nil];
			[subscribedValues addObject:@(index)];
		}
	});

	expect(subscribedValues.count).to.equal(count);
	expect(generatedValues.count).to.equal(count);
	expect(generatedValues).to.equal(subscribedValues);
});

SpecEnd
