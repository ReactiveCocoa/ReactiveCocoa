//
//  RACSubscriberExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-27.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriberExamples.h"

#import "RACDisposable.h"
#import "RACSubject.h"
#import "RACSubscriber.h"

NSString * const RACSubscriberExamples = @"RACSubscriberExamples";
NSString * const RACSubscriberExampleSubscriber = @"RACSubscriberExampleSubscriber";
NSString * const RACSubscriberExampleValuesReceivedBlock = @"RACSubscriberExampleValuesReceivedBlock";
NSString * const RACSubscriberExampleErrorReceivedBlock = @"RACSubscriberExampleErrorReceivedBlock";
NSString * const RACSubscriberExampleSuccessBlock = @"RACSubscriberExampleSuccessBlock";

SharedExampleGroupsBegin(RACSubscriberExamples)

sharedExamplesFor(RACSubscriberExamples, ^(NSDictionary *data) {
	__block NSArray * (^valuesReceived)(void);
	__block NSError * (^errorReceived)(void);
	__block BOOL (^success)(void);
	__block id<RACSubscriber> subscriber;
	
	beforeEach(^{
		valuesReceived = data[RACSubscriberExampleValuesReceivedBlock];
		errorReceived = data[RACSubscriberExampleErrorReceivedBlock];
		success = data[RACSubscriberExampleSuccessBlock];
		subscriber = data[RACSubscriberExampleSubscriber];
		expect(subscriber).notTo.beNil();
	});

	it(@"should accept a nil error", ^{
		[subscriber sendError:nil];

		expect(success()).to.beFalsy();
		expect(errorReceived()).to.beNil();
		expect(valuesReceived()).to.equal(@[]);
	});

	describe(@"with values", ^{
		__block NSSet *values;
		
		beforeEach(^{
			NSMutableSet *mutableValues = [NSMutableSet set];
			for (NSUInteger i = 0; i < 20; i++) {
				[mutableValues addObject:@(i)];
			}

			values = [mutableValues copy];
		});

		it(@"should send nexts serially, even when delivered from multiple threads", ^{
			NSArray *allValues = values.allObjects;
			dispatch_apply(allValues.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), [^(size_t index) {
				[subscriber sendNext:allValues[index]];
			} copy]);

			expect(success()).to.beTruthy();
			expect(errorReceived()).to.beNil();

			NSSet *valuesReceivedSet = [NSSet setWithArray:valuesReceived()];
			expect(valuesReceivedSet).to.equal(values);
		});
	});

	describe(@"multiple subscriptions", ^{
		__block RACSubject *first;
		__block RACSubject *second;

		beforeEach(^{
			first = [RACSubject subject];
			[first subscribe:subscriber];

			second = [RACSubject subject];
			[second subscribe:subscriber];
		});

		it(@"should send values from all subscriptions", ^{
			[first sendNext:@"foo"];
			[second sendNext:@"bar"];
			[first sendNext:@"buzz"];
			[second sendNext:@"baz"];

			expect(success()).to.beTruthy();
			expect(errorReceived()).to.beNil();

			NSArray *expected = @[ @"foo", @"bar", @"buzz", @"baz" ];
			expect(valuesReceived()).to.equal(expected);
		});

		it(@"should terminate after the first error from any subscription", ^{
			NSError *error = [NSError errorWithDomain:@"" code:-1 userInfo:nil];

			[first sendNext:@"foo"];
			[second sendError:error];
			[first sendNext:@"buzz"];

			expect(success()).to.beFalsy();
			expect(errorReceived()).to.equal(error);

			NSArray *expected = @[ @"foo" ];
			expect(valuesReceived()).to.equal(expected);
		});

		it(@"should terminate after the first completed from any subscription", ^{
			[first sendNext:@"foo"];
			[second sendNext:@"bar"];
			[first sendCompleted];
			[second sendNext:@"baz"];

			expect(success()).to.beTruthy();
			expect(errorReceived()).to.beNil();

			NSArray *expected = @[ @"foo", @"bar" ];
			expect(valuesReceived()).to.equal(expected);
		});

		it(@"should dispose of all current subscriptions upon termination", ^{
			__block BOOL firstDisposed = NO;
			RACSignal *firstDisposableSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
				return [RACDisposable disposableWithBlock:^{
					firstDisposed = YES;
				}];
			}];

			__block BOOL secondDisposed = NO;
			RACSignal *secondDisposableSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
				return [RACDisposable disposableWithBlock:^{
					secondDisposed = YES;
				}];
			}];

			[firstDisposableSignal subscribe:subscriber];
			[secondDisposableSignal subscribe:subscriber];
			
			expect(firstDisposed).to.beFalsy();
			expect(secondDisposed).to.beFalsy();

			[first sendCompleted];

			expect(firstDisposed).to.beTruthy();
			expect(secondDisposed).to.beTruthy();
		});

		it(@"should dispose of future subscriptions upon termination", ^{
			__block BOOL disposed = NO;
			RACSignal *disposableSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
				return [RACDisposable disposableWithBlock:^{
					disposed = YES;
				}];
			}];

			[first sendCompleted];
			expect(disposed).to.beFalsy();

			[disposableSignal subscribe:subscriber];
			expect(disposed).to.beTruthy();
		});
	});
});

SharedExampleGroupsEnd
