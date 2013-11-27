//
//  RACQueuedSignalGeneratorSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACQueuedSignalGenerator.h"
#import "RACDisposable.h"
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

	generator = [[[RACDynamicSignalGenerator alloc]
		initWithBlock:^(RACSignal *input) {
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

SpecEnd
