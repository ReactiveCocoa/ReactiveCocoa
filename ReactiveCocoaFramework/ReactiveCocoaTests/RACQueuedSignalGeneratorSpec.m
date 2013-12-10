//
//  RACQueuedSignalGeneratorSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACQueuedSignalGenerator.h"
#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSignalGenerator+Operations.h"
#import "RACSubject.h"
#import "RACUnit.h"

SpecBegin(RACQueuedSignalGenerator)

__block RACQueuedSignalGenerator *generator;
__block NSUInteger generationCount;
__block NSUInteger subscriptionCount;
__block NSUInteger disposedCount;

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
		serialize];
	
	expect(generator).notTo.beNil();
});

it(@"should only invoke the inner generator upon subscription", ^{
	RACSubject *subject = [RACSubject subject];
	RACSignal *signal = [generator signalWithValue:subject];
	expect(signal).notTo.beNil();

	expect(generationCount).to.equal(0);
	expect(subscriptionCount).to.equal(0);

	__block id next = nil;
	[signal subscribeNext:^(id x) {
		next = x;
	}];

	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(1);

	expect(next).to.beNil();
	expect(disposedCount).to.equal(0);

	[subject sendNext:RACUnit.defaultUnit];

	expect(next).to.equal(RACUnit.defaultUnit);
	expect(disposedCount).to.equal(0);

	[subject sendError:nil];

	expect(disposedCount).to.equal(1);
	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(1);
});

it(@"should dispose of the generated signal", ^{
	RACSubject *subject = [RACSubject subject];
	RACSignal *signal = [generator signalWithValue:subject];
	expect(signal).notTo.beNil();

	RACDisposable *disposable = [signal subscribeCompleted:^{}];
	expect(disposable).notTo.beNil();

	expect(disposedCount).to.equal(0);
	[disposable dispose];
	expect(disposedCount).to.equal(1);
});

it(@"should generate further signals as previous ones are disposed", ^{
	RACSubject *firstSubject = [RACSubject subject];
	RACSignal *firstSignal = [generator signalWithValue:firstSubject];
	expect(firstSignal).notTo.beNil();

	RACSubject *secondSubject = [RACSubject subject];
	RACSignal *secondSignal = [generator signalWithValue:secondSubject];
	expect(secondSignal).notTo.beNil();

	RACSubject *thirdSubject = [RACSubject subject];
	RACSignal *thirdSignal = [generator signalWithValue:thirdSubject];
	expect(thirdSignal).notTo.beNil();

	RACSubject *fourthSubject = [RACSubject subject];
	RACSignal *fourthSignal = [generator signalWithValue:fourthSubject];
	expect(fourthSignal).notTo.beNil();

	expect(generationCount).to.equal(0);
	expect(subscriptionCount).to.equal(0);

	__block id firstValue = nil;
	RACDisposable *firstDisposable = [firstSignal subscribeNext:^(id x) {
		firstValue = x;
	}];

	__block id secondValue = nil;
	RACDisposable *secondDisposable = [secondSignal subscribeNext:^(id x) {
		secondValue = x;
	}];

	__block id thirdValue = nil;
	RACDisposable *thirdDisposable = [thirdSignal subscribeNext:^(id x) {
		thirdValue = x;
	}];

	__block id fourthValue = nil;
	RACDisposable *fourthDisposable = [fourthSignal subscribeNext:^(id x) {
		fourthValue = x;
	}];

	expect(firstDisposable).notTo.beNil();
	expect(secondDisposable).notTo.beNil();
	expect(thirdDisposable).notTo.beNil();
	expect(fourthDisposable).notTo.beNil();

	expect(generationCount).to.equal(1);
	expect(subscriptionCount).to.equal(1);

	[firstSubject sendNext:@1];
	[secondSubject sendNext:@1];
	[thirdSubject sendNext:@1];
	[fourthSubject sendNext:@1];

	expect(firstValue).to.equal(@1);
	expect(secondValue).to.beNil();
	expect(thirdValue).to.beNil();
	expect(fourthValue).to.beNil();

	[firstDisposable dispose];

	expect(generationCount).to.equal(2);
	expect(subscriptionCount).to.equal(2);

	[secondSubject sendNext:@2];
	[thirdSubject sendNext:@2];
	[fourthSubject sendNext:@2];

	expect(secondValue).to.equal(@2);
	expect(thirdValue).to.beNil();
	expect(fourthValue).to.beNil();

	[secondSubject sendError:nil];

	expect(generationCount).to.equal(3);
	expect(subscriptionCount).to.equal(3);

	[thirdSubject sendNext:@3];
	[fourthSubject sendNext:@3];

	expect(thirdValue).to.equal(@3);
	expect(fourthValue).to.beNil();

	[thirdSubject sendCompleted];

	expect(generationCount).to.equal(4);
	expect(subscriptionCount).to.equal(4);

	[fourthSubject sendNext:@4];
	expect(fourthValue).to.equal(@4);
});

it(@"should complete signal properties after the generator deallocates", ^{
	__block BOOL deallocated = NO;
	__block BOOL executingCompleted = NO;
	__block BOOL enqueuedSignalsCompleted = NO;

	@autoreleasepool {
		RACQueuedSignalGenerator *generator __attribute__((objc_precise_lifetime)) = [[RACDynamicSignalGenerator
			generatorWithBlock:^(RACSignal *input) {
				return input;
			}]
			serialize];
		
		[generator.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocated = YES;
		}]];

		[generator.executing subscribeCompleted:^{
			executingCompleted = YES;
		}];

		[generator.enqueuedSignals subscribeCompleted:^{
			enqueuedSignalsCompleted = YES;
		}];

		[[generator signalWithValue:[RACSignal empty]] subscribeCompleted:^{}];
		expect(deallocated).to.beFalsy();
		expect(executingCompleted).to.beFalsy();
		expect(enqueuedSignalsCompleted).to.beFalsy();
	}

	expect(deallocated).will.beTruthy();
	expect(executingCompleted).to.beTruthy();
	expect(enqueuedSignalsCompleted).to.beTruthy();
});

describe(@"executing", ^{
	it(@"should send NO before any signals are enqueued", ^{
		expect([generator.executing first]).to.equal(@NO);
	});

	it(@"should send YES once a generated signal is subscribed to", ^{
		RACSignal *signal = [generator signalWithValue:[RACSubject subject]];
		expect([generator.executing first]).to.equal(@NO);
		
		[signal subscribeCompleted:^{}];
		expect([generator.executing first]).to.equal(@YES);
	});

	it(@"should send YES while subscriptions are waiting", ^{
		NSMutableArray *executing = [NSMutableArray array];
		[generator.executing subscribeNext:^(NSNumber *b) {
			[executing addObject:b];
		}];

		RACSubject *firstSubject = [RACSubject subject];
		RACSignal *firstSignal = [generator signalWithValue:firstSubject];
		expect(firstSignal).notTo.beNil();

		RACSubject *secondSubject = [RACSubject subject];
		RACSignal *secondSignal = [generator signalWithValue:secondSubject];
		expect(secondSignal).notTo.beNil();

		expect(executing).to.equal((@[ @NO ]));

		[firstSignal subscribeCompleted:^{}];
		expect(executing).to.equal((@[ @NO, @YES ]));
		
		RACDisposable *secondDisposable = [secondSignal subscribeCompleted:^{}];
		expect(executing).to.equal((@[ @NO, @YES ]));

		[firstSubject sendCompleted];
		expect(executing).to.equal((@[ @NO, @YES ]));

		[secondDisposable dispose];
		expect(executing).to.equal((@[ @NO, @YES, @NO ]));
	});
});

describe(@"enqueuedSignals", ^{
	__block RACSignal *enqueuedSignal;

	beforeEach(^{
		enqueuedSignal = nil;

		[generator.enqueuedSignals subscribeNext:^(RACSignal *signal) {
			expect(signal).notTo.beNil();
			enqueuedSignal = signal;
		}];
	});

	it(@"should send when a generated signal is subscribed to", ^{
		RACSignal *signal = [generator signalWithValue:[RACSubject subject]];
		expect(enqueuedSignal).to.beNil();
		
		[signal subscribeCompleted:^{}];
		expect(enqueuedSignal).notTo.beNil();
	});

	it(@"should forward events from the generated signal without duplicating side effects", ^{
		RACSubject *subject = [RACSubject subject];
		RACSignal *signal = [generator signalWithValue:subject];

		[signal subscribeCompleted:^{}];
		expect(subscriptionCount).to.equal(1);

		__block id value = nil;
		__block NSError *error = nil;
		[enqueuedSignal subscribeNext:^(id x) {
			value = x;
		} error:^(NSError *e) {
			error = e;
		}];

		expect(value).to.beNil();
		expect(error).to.beNil();
		expect(subscriptionCount).to.equal(1);

		[subject sendNext:@"foo"];
		expect(value).to.equal(@"foo");

		NSError *testError = [NSError errorWithDomain:@"RACQueuedSignalGeneratorSpec" code:1 userInfo:nil];
		[subject sendError:testError];

		expect(value).to.equal(@"foo");
		expect(error).to.equal(testError);
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should complete the enqueued signal when the generated signal is disposed", ^{
		RACSubject *subject = [RACSubject subject];
		RACSignal *signal = [generator signalWithValue:subject];

		RACDisposable *disposable = [signal subscribeCompleted:^{}];
		expect(disposable).notTo.beNil();

		__block BOOL completed = NO;
		[enqueuedSignal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();

		[disposable dispose];
		expect(completed).to.beTruthy();
	});

	it(@"should send signals in the order they're enqueued", ^{
		const size_t count = 100;

		NSMutableArray *enqueuedValues = [NSMutableArray array];
		[[generator.enqueuedSignals
			flatten]
			subscribeNext:^(NSNumber *num) {
				[enqueuedValues addObject:num];
			}];

		NSMutableArray *subscribedValues = [NSMutableArray array];

		dispatch_apply(count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t index) {
			RACSignal *signal = [generator signalWithValue:[RACSignal return:@(index)]];

			[signal subscribeNext:^(NSNumber *num) {
				@synchronized (subscribedValues) {
					[subscribedValues addObject:num];
				}
			}];
		});

		expect(subscribedValues.count).to.equal(count);
		expect(enqueuedValues.count).to.equal(count);
		expect(enqueuedValues).to.equal(subscribedValues);
	});
});

SpecEnd
