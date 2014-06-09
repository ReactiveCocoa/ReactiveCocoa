//
//  RACSignalSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySignalExamples.h"
#import "RACSequenceExamples.h"
#import "RACStreamExamples.h"
#import "RACTestObject.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBehaviorSubject.h"
#import "RACCommand.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACEvent.h"
#import "RACGroupedSignal.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSignalStartExamples.h"
#import "RACSubject.h"
#import "RACSubscriber+Private.h"
#import "RACSubscriber.h"
#import "RACTestScheduler.h"
#import "RACTuple.h"
#import "RACUnit.h"
#import <libkern/OSAtomic.h>

// Set in a beforeAll below.
static NSError *RACSignalTestError;

static NSString * const RACSignalMergeConcurrentCompletionExampleGroup = @"RACSignalMergeConcurrentCompletionExampleGroup";
static NSString * const RACSignalMaxConcurrent = @"RACSignalMaxConcurrent";
SharedExampleGroupsBegin(mergeConcurrentCompletionName);

sharedExamplesFor(RACSignalMergeConcurrentCompletionExampleGroup, ^(NSDictionary *data) {
	it(@"should complete only after the source and all its signals have completed", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];
		RACSubject *subject3 = [RACSubject subject];

		RACSubject *signalsSubject = [RACSubject subject];
		__block BOOL completed = NO;
		[[signalsSubject flatten:[data[RACSignalMaxConcurrent] unsignedIntegerValue]] subscribeCompleted:^{
			completed = YES;
		}];

		[signalsSubject sendNext:subject1];
		[subject1 sendCompleted];

		expect(completed).to.beFalsy();

		[signalsSubject sendNext:subject2];
		[signalsSubject sendNext:subject3];

		[signalsSubject sendCompleted];

		expect(completed).to.beFalsy();

		[subject2 sendCompleted];

		expect(completed).to.beFalsy();

		[subject3 sendCompleted];

		expect(completed).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SpecBegin(RACSignal)

beforeAll(^{
	// We do this instead of a macro to ensure that to.equal() will work
	// correctly (by matching identity), even if -[NSError isEqual:] is broken.
	RACSignalTestError = [NSError errorWithDomain:@"foo" code:100 userInfo:nil];
});

describe(@"RACStream", ^{
	id verifyValues = ^(RACSignal *signal, NSArray *expectedValues) {
		expect(signal).notTo.beNil();

		NSMutableArray *collectedValues = [NSMutableArray array];

		__block BOOL success = NO;
		__block NSError *error = nil;
		[signal subscribeNext:^(id value) {
			[collectedValues addObject:value];
		} error:^(NSError *receivedError) {
			error = receivedError;
		} completed:^{
			success = YES;
		}];

		expect(success).will.beTruthy();
		expect(error).to.beNil();
		expect(collectedValues).to.equal(expectedValues);
	};

	RACSignal *infiniteSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block volatile int32_t done = 0;

		[RACScheduler.mainThreadScheduler schedule:^{
			while (!done) {
				[subscriber sendNext:RACUnit.defaultUnit];
			}
		}];

		return [RACDisposable disposableWithBlock:^{
			OSAtomicIncrement32Barrier(&done);
		}];
	}];

	itShouldBehaveLike(RACStreamExamples, ^{
		return @{
			RACStreamExamplesClass: RACSignal.class,
			RACStreamExamplesVerifyValuesBlock: verifyValues,
			RACStreamExamplesInfiniteStream: infiniteSignal
		};
	});
});

describe(@"-bind:", ^{
	__block RACSubject *signals;
	__block BOOL disposed;
	__block id lastValue;
	__block RACSubject *values;

	beforeEach(^{
		// Tests send a (RACSignal, BOOL) pair that are used below in -bind:.
		signals = [RACSubject subject];

		disposed = NO;
		RACSignal *source = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			[signals subscribe:subscriber];

			return [RACDisposable disposableWithBlock:^{
				disposed = YES;
			}];
		}];

		RACSignal *bind = [source bind:^{
			return ^(RACTuple *x, BOOL *stop) {
				RACTupleUnpack(RACSignal *signal, NSNumber *stopValue) = x;
				*stop = stopValue.boolValue;
				return signal;
			};
		}];

		lastValue = nil;
		[bind subscribeNext:^(id x) {
			lastValue = x;
		}];

		// Send `bind` an open ended subject to subscribe to. These tests make
		// use of this in two ways:
		//   1. Used to test a regression bug where -bind: would not actually
		//      stop when instructed to. This bug manifested itself only when
		//      there were subscriptions that lived on past the point at which
		//      -bind: was stopped. This subject represents such a subscription.
		//   2. Test that values sent by this subject are received by `bind`'s
		//      subscriber, even *after* -bind: has been instructed to stop.
		values = [RACSubject subject];
		[signals sendNext:RACTuplePack(values, @NO)];
		expect(disposed).to.beFalsy();
	});

	it(@"should dispose source signal when stopped with nil signal", ^{
		// Tell -bind: to stop by sending it a `nil` signal.
		[signals sendNext:RACTuplePack(nil, @NO)];
		expect(disposed).to.beTruthy();

		// Should still receive values sent after stopping.
		expect(lastValue).to.beNil();
		[values sendNext:RACUnit.defaultUnit];
		expect(lastValue).to.equal(RACUnit.defaultUnit);
	});

	it(@"should dispose source signal when stop flag set to YES", ^{
		// Tell -bind: to stop by setting the stop flag to YES.
		[signals sendNext:RACTuplePack([RACSignal return:@1], @YES)];
		expect(disposed).to.beTruthy();

		// Should still recieve last signal sent at the time of setting stop to YES.
		expect(lastValue).to.equal(@1);

		// Should still receive values sent after stopping.
		[values sendNext:@2];
		expect(lastValue).to.equal(@2);
	});

	it(@"should properly stop subscribing to new signals after error", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@0];
			[subscriber sendNext:@1];
			return nil;
		}];

		__block BOOL subscribedAfterError = NO;
		RACSignal *bind = [signal bind:^{
			return ^(NSNumber *x, BOOL *stop) {
				if (x.integerValue == 0) return [RACSignal error:nil];

				return [RACSignal defer:^{
					subscribedAfterError = YES;
					return [RACSignal empty];
				}];
			};
		}];

		[bind subscribeCompleted:^{}];
		expect(subscribedAfterError).to.beFalsy();
	});

	it(@"should not subscribe to signals following error in +merge:", ^{
		__block BOOL firstSubscribed = NO;
		__block BOOL secondSubscribed = NO;
		__block BOOL errored = NO;

		RACSignal *signal = [[RACSignal
			merge:@[
				[RACSignal defer:^{
					firstSubscribed = YES;
					return [RACSignal error:nil];
				}],
				[RACSignal defer:^{
					secondSubscribed = YES;
					return [RACSignal return:nil];
				}]
			]]
			doError:^(NSError *error) {
				errored = YES;
			}];

		[signal subscribeCompleted:^{}];

		expect(firstSubscribed).to.beTruthy();
		expect(secondSubscribed).to.beFalsy();
		expect(errored).to.beTruthy();
	});
});

describe(@"subscribing", ^{
	__block RACSignal *signal = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should get next values", ^{
		__block id nextValueReceived = nil;
		[signal subscribeNext:^(id x) {
			nextValueReceived = x;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(nextValueReceived).to.equal(nextValueSent);
	});
	
	it(@"should get completed", ^{
		__block BOOL didGetCompleted = NO;
		[signal subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			
		} completed:^{
			didGetCompleted = YES;
		}];
		
		expect(didGetCompleted).to.beTruthy();
	});
	
	it(@"should not get an error", ^{
		__block BOOL didGetError = NO;
		[signal subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			didGetError = YES;
		} completed:^{
			
		}];
		
		expect(didGetError).to.beFalsy();
	});
	
	it(@"shouldn't get anything after dispose", ^{
		RACTestScheduler *scheduler = [[RACTestScheduler alloc] init];
		NSMutableArray *receivedValues = [NSMutableArray array];

		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@0];

			[scheduler afterDelay:0 schedule:^{
				[subscriber sendNext:@1];
			}];

			return nil;
		}];

		RACDisposable *disposable = [signal subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		NSArray *expectedValues = @[ @0 ];
		expect(receivedValues).to.equal(expectedValues);
		
		[disposable dispose];
		[scheduler stepAll];
		
		expect(receivedValues).to.equal(expectedValues);
	});

	it(@"should have a current scheduler in didSubscribe block", ^{
		__block RACScheduler *currentScheduler;
		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			currentScheduler = RACScheduler.currentScheduler;
			[subscriber sendCompleted];
			return nil;
		}];

		[signal subscribeNext:^(id x) {}];
		expect(currentScheduler).notTo.beNil();

		currentScheduler = nil;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[signal subscribeNext:^(id x) {}];
		});
		expect(currentScheduler).willNot.beNil();
	});
	
	it(@"should automatically dispose of other subscriptions from +createSignal:", ^{
		__block BOOL innerDisposed = NO;

		RACSignal *innerSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}];
		}];

		RACSignal *outerSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[innerSignal subscribe:subscriber];
			return nil;
		}];

		RACDisposable *disposable = [outerSignal subscribeCompleted:^{}];
		expect(disposable).notTo.beNil();
		expect(innerDisposed).to.beFalsy();

		[disposable dispose];
		expect(innerDisposed).to.beTruthy();
	});
});

describe(@"-takeUntil:", ^{
	it(@"should support value as trigger", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];

		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];

		[cutOffSubject sendNext:[RACUnit defaultUnit]];

		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});
    
	it(@"should support completion as trigger", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];
        
		[cutOffSubject sendCompleted];
        
		shouldBeGettingItems = NO;
		[subject sendNext:@"should not go through"];
	});

	it(@"should squelch any values sent immediately upon subscription", ^{
		RACSignal *valueSignal = [RACSignal return:RACUnit.defaultUnit];
		RACSignal *cutOffSignal = [RACSignal empty];

		__block BOOL gotNext = NO;
		__block BOOL completed = NO;

		[[valueSignal takeUntil:cutOffSignal] subscribeNext:^(id _) {
			gotNext = YES;
		} completed:^{
			completed = YES;
		}];

		expect(gotNext).to.beFalsy();
		expect(completed).to.beTruthy();
	});
});

describe(@"-takeUntilReplacement:", ^{
	it(@"should forward values from the receiver until it's replaced", ^{
		RACSubject *receiver = [RACSubject subject];
		RACSubject *replacement = [RACSubject subject];

		NSMutableArray *receivedValues = [NSMutableArray array];

		[[receiver takeUntilReplacement:replacement] subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		expect(receivedValues).to.equal(@[]);

		[receiver sendNext:@1];
		expect(receivedValues).to.equal(@[ @1 ]);

		[receiver sendNext:@2];
		expect(receivedValues).to.equal((@[ @1, @2 ]));

		[replacement sendNext:@3];
		expect(receivedValues).to.equal((@[ @1, @2, @3 ]));

		[receiver sendNext:@4];
		expect(receivedValues).to.equal((@[ @1, @2, @3 ]));

		[replacement sendNext:@5];
		expect(receivedValues).to.equal((@[ @1, @2, @3, @5 ]));
	});

	it(@"should forward error from the receiver", ^{
		RACSubject *receiver = [RACSubject subject];
		__block BOOL receivedError = NO;

		[[receiver takeUntilReplacement:RACSignal.never] subscribeError:^(NSError *error) {
			receivedError = YES;
		}];

		[receiver sendError:nil];
		expect(receivedError).to.beTruthy();
	});

	it(@"should not forward completed from the receiver", ^{
		RACSubject *receiver = [RACSubject subject];
		__block BOOL receivedCompleted = NO;

		[[receiver takeUntilReplacement:RACSignal.never] subscribeCompleted: ^{
			receivedCompleted = YES;
		}];

		[receiver sendCompleted];
		expect(receivedCompleted).to.beFalsy();
	});

	it(@"should forward error from the replacement signal", ^{
		RACSubject *replacement = [RACSubject subject];
		__block BOOL receivedError = NO;

		[[RACSignal.never takeUntilReplacement:replacement] subscribeError:^(NSError *error) {
			receivedError = YES;
		}];

		[replacement sendError:nil];
		expect(receivedError).to.beTruthy();
	});

	it(@"should forward completed from the replacement signal", ^{
		RACSubject *replacement = [RACSubject subject];
		__block BOOL receivedCompleted = NO;

		[[RACSignal.never takeUntilReplacement:replacement] subscribeCompleted: ^{
			receivedCompleted = YES;
		}];

		[replacement sendCompleted];
		expect(receivedCompleted).to.beTruthy();
	});
	
	it(@"should not forward values from the receiver if both send synchronously", ^{
		RACSignal *receiver = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			return nil;
		}];
		RACSignal *replacement = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@4];
			[subscriber sendNext:@5];
			[subscriber sendNext:@6];
			return nil;
		}];

		NSMutableArray *receivedValues = [NSMutableArray array];

		[[receiver takeUntilReplacement:replacement] subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];

		expect(receivedValues).to.equal((@[ @4, @5, @6 ]));
	});

	it(@"should dispose of the receiver when it's disposed of", ^{
		__block BOOL receiverDisposed = NO;
		RACSignal *receiver = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				receiverDisposed = YES;
			}];
		}];

		[[[receiver takeUntilReplacement:RACSignal.never] subscribeCompleted:^{}] dispose];

		expect(receiverDisposed).to.beTruthy();
	});

	it(@"should dispose of the replacement signal when it's disposed of", ^{
		__block BOOL replacementDisposed = NO;
		RACSignal *replacement = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				replacementDisposed = YES;
			}];
		}];

		[[[RACSignal.never takeUntilReplacement:replacement] subscribeCompleted:^{}] dispose];

		expect(replacementDisposed).to.beTruthy();
	});

	it(@"should dispose of the receiver when the replacement signal sends an event", ^{
		__block BOOL receiverDisposed = NO;
		RACSignal *receiver = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				receiverDisposed = YES;
			}];
		}];
		RACSubject *replacement = [RACSubject subject];

		[[receiver takeUntilReplacement:replacement] subscribeCompleted:^{}];

		expect(receiverDisposed).to.beFalsy();

		[replacement sendNext:nil];
		
		expect(receiverDisposed).to.beTruthy();
	});
});

describe(@"disposal", ^{
	it(@"should dispose of the didSubscribe disposable", ^{
		__block BOOL innerDisposed = NO;
		RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}];
		}];

		expect(innerDisposed).to.beFalsy();

		RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
		expect(disposable).notTo.beNil();

		[disposable dispose];
		expect(innerDisposed).to.beTruthy();
	});

	it(@"should dispose of the didSubscribe disposable asynchronously", ^{
		__block BOOL innerDisposed = NO;
		RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}];
		}];

		[[RACScheduler scheduler] schedule:^{
			RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
			[disposable dispose];
		}];

		expect(innerDisposed).will.beTruthy();
	});
});

describe(@"querying", ^{
	__block RACSignal *signal = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendNext:@"other value"];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should return first 'next' value with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendCompleted];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@1);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return first default value with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendCompleted];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return error with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendError:RACSignalTestError];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"shouldn't crash when returning an error from a background scheduler", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[[RACScheduler scheduler] schedule:^{
				[subscriber sendError:RACSignalTestError];
			}];

			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should terminate the subscription after returning from -firstOrDefault:success:error:", ^{
		__block BOOL disposed = NO;
		RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:RACUnit.defaultUnit];

			return [RACDisposable disposableWithBlock:^{
				disposed = YES;
			}];
		}];

		expect(signal).notTo.beNil();
		expect(disposed).to.beFalsy();

		expect([signal firstOrDefault:nil success:NULL error:NULL]).to.equal(RACUnit.defaultUnit);
		expect(disposed).to.beTruthy();
	});

	it(@"should return YES from -waitUntilCompleted: when successful", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:RACUnit.defaultUnit];
			[subscriber sendCompleted];
			return nil;
		}];

		__block NSError *error = nil;
		expect([signal waitUntilCompleted:&error]).to.beTruthy();
		expect(error).to.beNil();
	});

	it(@"should return NO from -waitUntilCompleted: upon error", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:RACUnit.defaultUnit];
			[subscriber sendError:RACSignalTestError];
			return nil;
		}];

		__block NSError *error = nil;
		expect([signal waitUntilCompleted:&error]).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should return a delayed value from -asynchronousFirstOrDefault:success:error:", ^{
		RACSignal *signal = [[RACSignal return:RACUnit.defaultUnit] delay:0];

		__block BOOL scheduledBlockRan = NO;
		[RACScheduler.mainThreadScheduler schedule:^{
			scheduledBlockRan = YES;
		}];

		expect(scheduledBlockRan).to.beFalsy();

		BOOL success = NO;
		NSError *error = nil;
		id value = [signal asynchronousFirstOrDefault:nil success:&success error:&error];

		expect(scheduledBlockRan).to.beTruthy();

		expect(value).to.equal(RACUnit.defaultUnit);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});

	it(@"should return a default value from -asynchronousFirstOrDefault:success:error:", ^{
		RACSignal *signal = [[RACSignal error:RACSignalTestError] delay:0];

		__block BOOL scheduledBlockRan = NO;
		[RACScheduler.mainThreadScheduler schedule:^{
			scheduledBlockRan = YES;
		}];

		expect(scheduledBlockRan).to.beFalsy();

		BOOL success = NO;
		NSError *error = nil;
		id value = [signal asynchronousFirstOrDefault:RACUnit.defaultUnit success:&success error:&error];

		expect(scheduledBlockRan).to.beTruthy();

		expect(value).to.equal(RACUnit.defaultUnit);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should return a delayed error from -asynchronousFirstOrDefault:success:error:", ^{
		RACSignal *signal = [[RACSignal
			createSignal:^(id<RACSubscriber> subscriber) {
				return [[RACScheduler scheduler] schedule:^{
					[subscriber sendError:RACSignalTestError];
				}];
			}]
			deliverOn:RACScheduler.mainThreadScheduler];

		__block NSError *error = nil;
		__block BOOL success = NO;
		expect([signal asynchronousFirstOrDefault:nil success:&success error:&error]).to.beNil();

		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should terminate the subscription after returning from -asynchronousFirstOrDefault:success:error:", ^{
		__block BOOL disposed = NO;
		RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			[[RACScheduler scheduler] schedule:^{
				[subscriber sendNext:RACUnit.defaultUnit];
			}];

			return [RACDisposable disposableWithBlock:^{
				disposed = YES;
			}];
		}];

		expect(signal).notTo.beNil();
		expect(disposed).to.beFalsy();

		expect([signal asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal(RACUnit.defaultUnit);
		expect(disposed).will.beTruthy();
	});

	it(@"should return a delayed success from -asynchronouslyWaitUntilCompleted:", ^{
		RACSignal *signal = [[RACSignal return:RACUnit.defaultUnit] delay:0];

		__block BOOL scheduledBlockRan = NO;
		[RACScheduler.mainThreadScheduler schedule:^{
			scheduledBlockRan = YES;
		}];

		expect(scheduledBlockRan).to.beFalsy();

		NSError *error = nil;
		BOOL success = [signal asynchronouslyWaitUntilCompleted:&error];

		expect(scheduledBlockRan).to.beTruthy();

		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
});

describe(@"continuation", ^{
	it(@"should repeat after completion", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACScheduler *scheduler = [RACScheduler scheduler];

		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			return [scheduler schedule:^{
				if (numberOfSubscriptions == 3) {
					[subscriber sendError:RACSignalTestError];
					return;
				}
				
				numberOfSubscriptions++;
				
				[subscriber sendNext:@"1"];
				[subscriber sendCompleted];
				[subscriber sendError:RACSignalTestError];
			}];
		}];
		
		__block NSUInteger nextCount = 0;
		__block BOOL gotCompleted = NO;
		[[signal repeat] subscribeNext:^(id x) {
			nextCount++;
		} error:^(NSError *error) {
			
		} completed:^{
			gotCompleted = YES;
		}];
		
		expect(nextCount).will.equal(3);
		expect(gotCompleted).to.beFalsy();
	});

	it(@"should stop repeating when disposed", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		__block RACDisposable *disposable = [[signal repeat] subscribeNext:^(id x) {
			[values addObject:x];
			[disposable dispose];
		} completed:^{
			completed = YES;
		}];

		expect(values).will.equal(@[ @1 ]);
		expect(completed).to.beFalsy();
	});

	it(@"should stop repeating when disposed by -take:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		[[[signal repeat] take:1] subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		expect(values).will.equal(@[ @1 ]);
		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatestWith:", ^{
	__block RACSubject *subject1 = nil;
	__block RACSubject *subject2 = nil;
	__block RACSignal *combined = nil;
	
	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		combined = [RACSignal combineLatest:@[ subject1, subject2 ]];
	});
	
	it(@"should send next only once both signals send next", ^{
		__block RACTuple *tuple;
		
		[combined subscribeNext:^(id x) {
			tuple = x;
		}];
		
		expect(tuple).to.beNil();

		[subject1 sendNext:@"1"];
		expect(tuple).to.beNil();

		[subject2 sendNext:@"2"];
		expect(tuple).to.equal(RACTuplePack(@"1", @"2"));
	});
	
	it(@"should send nexts when either signal sends multiple times", ^{
		NSMutableArray *results = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[results addObject:x];
		}];
		
		[subject1 sendNext:@"1"];
		[subject2 sendNext:@"2"];
		
		[subject1 sendNext:@"3"];
		[subject2 sendNext:@"4"];
		
		expect(results[0]).to.equal(RACTuplePack(@"1", @"2"));
		expect(results[1]).to.equal(RACTuplePack(@"3", @"2"));
		expect(results[2]).to.equal(RACTuplePack(@"3", @"4"));
	});
	
	it(@"should complete when only both signals complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();
		
		[subject1 sendCompleted];
		expect(completed).to.beFalsy();

		[subject2 sendCompleted];
		expect(completed).to.beTruthy();
	});
	
	it(@"should error when either signal errors", ^{
		__block NSError *receivedError = nil;
		[combined subscribeError:^(NSError *error) {
			receivedError = error;
		}];
		
		[subject1 sendError:RACSignalTestError];
		expect(receivedError).to.equal(RACSignalTestError);
	});

	it(@"shouldn't create a retain cycle", ^{
		__block BOOL subjectDeallocd = NO;
		__block BOOL signalDeallocd = NO;

		@autoreleasepool {
			RACSubject *subject __attribute__((objc_precise_lifetime)) = [RACSubject subject];
			[subject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				subjectDeallocd = YES;
			}]];
			
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal combineLatest:@[ subject ]];
			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocd = YES;
			}]];

			[signal subscribeCompleted:^{}];
			[subject sendCompleted];
		}

		expect(subjectDeallocd).will.beTruthy();
		expect(signalDeallocd).will.beTruthy();
	});

	it(@"should combine the same signal", ^{
		RACSignal *combined = [subject1 combineLatestWith:subject1];

		__block RACTuple *tuple;
		[combined subscribeNext:^(id x) {
			tuple = x;
		}];
		
		[subject1 sendNext:@"foo"];
		expect(tuple).to.equal(RACTuplePack(@"foo", @"foo"));
		
		[subject1 sendNext:@"bar"];
		expect(tuple).to.equal(RACTuplePack(@"bar", @"bar"));
	});
    
	it(@"should combine the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@(++counter)];
			[subscriber sendCompleted];
			return nil;
		}];

		RACSignal *combined = [sideEffectingSignal combineLatestWith:sideEffectingSignal];
		expect(counter).to.equal(0);

		NSMutableArray *receivedValues = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(2);

		NSArray *expected = @[ RACTuplePack(@1, @2) ];
		expect(receivedValues).to.equal(expected);
	});
});

describe(@"+combineLatest:", ^{
	it(@"should return tuples even when only combining one signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block RACTuple *tuple;
		[[RACSignal combineLatest:@[ subject ]] subscribeNext:^(id x) {
			tuple = x;
		}];

		[subject sendNext:@"foo"];
		expect(tuple).to.equal(RACTuplePack(@"foo"));
	});

	it(@"should complete immediately when not given any signals", ^{
		RACSignal *signal = [RACSignal combineLatest:@[]];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});

	it(@"should only complete after all its signals complete", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];
		RACSubject *subject3 = [RACSubject subject];
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ]];

		__block BOOL completed = NO;
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();

		[subject1 sendCompleted];
		expect(completed).to.beFalsy();

		[subject2 sendCompleted];
		expect(completed).to.beFalsy();

		[subject3 sendCompleted];
		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatest:reduce:", ^{
	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;

	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		subject3 = [RACSubject subject];
	});

	it(@"should send nils for nil values", ^{
		__block id receivedVal1;
		__block id receivedVal2;
		__block id receivedVal3;

		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ] reduce:^ id (id val1, id val2, id val3) {
			receivedVal1 = val1;
			receivedVal2 = val2;
			receivedVal3 = val3;
			return nil;
		}];

		__block BOOL gotValue = NO;
		[combined subscribeNext:^(id x) {
			gotValue = YES;
		}];

		[subject1 sendNext:nil];
		[subject2 sendNext:nil];
		[subject3 sendNext:nil];

		expect(gotValue).to.beTruthy();
		expect(receivedVal1).to.beNil();
		expect(receivedVal2).to.beNil();
		expect(receivedVal3).to.beNil();
	});

	it(@"should send the return result of the reduce block", ^{
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ] reduce:^(NSString *string1, NSString *string2, NSString *string3) {
			return [NSString stringWithFormat:@"%@: %@%@", string1, string2, string3];
		}];

		__block id received;
		[combined subscribeNext:^(id x) {
			received = x;
		}];

		[subject1 sendNext:@"hello"];
		[subject2 sendNext:@"world"];
		[subject3 sendNext:@"!!1"];

		expect(received).to.equal(@"hello: world!!1");
	});
	
	it(@"should handle multiples of the same signals", ^{
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject1, subject3 ] reduce:^(NSString *string1, NSString *string2, NSString *string3, NSString *string4) {
			return [NSString stringWithFormat:@"%@ : %@ = %@ : %@", string1, string2, string3, string4];
		}];
		
		NSMutableArray *receivedValues = NSMutableArray.array;
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		[subject1 sendNext:@"apples"];
		expect(receivedValues.lastObject).to.beNil();
		
		[subject2 sendNext:@"oranges"];
		expect(receivedValues.lastObject).to.beNil();

		[subject3 sendNext:@"cattle"];
		expect(receivedValues.lastObject).to.equal(@"apples : oranges = apples : cattle");
		
		[subject1 sendNext:@"horses"];
		expect(receivedValues.lastObject).to.equal(@"horses : oranges = horses : cattle");
	});
    
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@(++counter)];
			[subscriber sendCompleted];
			return nil;
		}];

		RACSignal *combined = [RACSignal combineLatest:@[ sideEffectingSignal, sideEffectingSignal, sideEffectingSignal ] reduce:^(id x, id y, id z) {
			return [NSString stringWithFormat:@"%@%@%@", x, y, z];
		}];

		NSMutableArray *receivedValues = [NSMutableArray array];
		expect(counter).to.equal(0);
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(3);
		expect(receivedValues).to.equal(@[ @"123" ]);
	});
});

describe(@"distinctUntilChanged", ^{
	it(@"should only send values that are distinct from the previous value", ^{
		RACSignal *sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@2];
			[subscriber sendNext:@1];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ @1, @2, @1 ];
		expect(values).to.equal(expected);
	});

	it(@"shouldn't consider nils to always be distinct", ^{
		RACSignal *sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ @1, [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});

	it(@"should consider initial nil to be distinct", ^{
		RACSignal *sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});
});

describe(@"RACObserve", ^{
	__block RACTestObject *testObject;

	beforeEach(^{
		testObject = [[RACTestObject alloc] init];
	});

	it(@"should work with object properties", ^{
		NSArray *expected = @[ @"hello", @"world" ];
		testObject.objectValue = expected[0];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACObserve(testObject, objectValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.objectValue = expected[1];

		expect(valuesReceived).to.equal(expected);
	});

	it(@"should work with non-object properties", ^{
		NSArray *expected = @[ @42, @43 ];
		testObject.integerValue = [expected[0] integerValue];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACObserve(testObject, integerValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.integerValue = [expected[1] integerValue];

		expect(valuesReceived).to.equal(expected);
	});

	it(@"should read the initial value upon subscription", ^{
		testObject.objectValue = @"foo";

		RACSignal *signal = RACObserve(testObject, objectValue);
		testObject.objectValue = @"bar";

		expect([signal first]).to.equal(@"bar");
	});
});

describe(@"-setKeyPath:onObject:", ^{
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id nilValue, RACSignal *signal) {
		[signal setKeyPath:keyPath onObject:testObject nilValue:nilValue];
	};

	itShouldBehaveLike(RACPropertySignalExamples, ^{
		return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
	});

	it(@"shouldn't send values to dealloc'd objects", ^{
		RACSubject *subject = [RACSubject subject];
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[subject setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
			expect(testObject.objectValue).to.beNil();

			[subject sendNext:@1];
			expect(testObject.objectValue).to.equal(@1);

			[subject sendNext:@2];
			expect(testObject.objectValue).to.equal(@2);
		}

		// This shouldn't do anything.
		[subject sendNext:@3];
	});

	it(@"should allow a new derivation after the signal's completed", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACTestObject *testObject = [[RACTestObject alloc] init];
		[subject1 setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
		[subject1 sendCompleted];

		RACSubject *subject2 = [RACSubject subject];
		// This will assert if the previous completion didn't dispose of the
		// subscription.
		[subject2 setKeyPath:@keypath(testObject.objectValue) onObject:testObject];
	});

	it(@"should set the given value when nil is received", ^{
		RACSubject *subject = [RACSubject subject];
		RACTestObject *testObject = [[RACTestObject alloc] init];
		[subject setKeyPath:@keypath(testObject.integerValue) onObject:testObject nilValue:@5];

		[subject sendNext:@1];
		expect(testObject.integerValue).to.equal(1);

		[subject sendNext:nil];
		expect(testObject.integerValue).to.equal(5);

		[subject sendCompleted];
		expect(testObject.integerValue).to.equal(5);
	});

	it(@"should keep object alive over -sendNext:", ^{
		RACSubject *subject = [RACSubject subject];
		__block RACTestObject *testObject = [[RACTestObject alloc] init];
		__block id deallocValue;

		__unsafe_unretained RACTestObject *unsafeTestObject = testObject;
		[testObject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			deallocValue = unsafeTestObject.slowObjectValue;
		}]];

		[subject setKeyPath:@keypath(testObject.slowObjectValue) onObject:testObject];
		expect(testObject.slowObjectValue).to.beNil();

		// Attempt to deallocate concurrently.
		[[RACScheduler scheduler] afterDelay:0.01 schedule:^{
			testObject = nil;
		}];

		expect(deallocValue).to.beNil();
		[subject sendNext:@1];
		expect(deallocValue).to.equal(@1);
	});
});

describe(@"memory management", ^{
	it(@"should dealloc signals if the signal does nothing", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
				return nil;
			}];

			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
		}

		expect(deallocd).will.beTruthy();
	});

	it(@"should retain signals for a single run loop iteration", ^{
		__block BOOL deallocd = NO;

		@autoreleasepool {
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
				return nil;
			}];

			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
		}

		expect(deallocd).to.beFalsy();
		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc signals if the signal immediately completes", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			__block BOOL done = NO;

			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
				[subscriber sendCompleted];
				return nil;
			}];

			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];

			[signal subscribeCompleted:^{
				done = YES;
			}];

			expect(done).will.beTruthy();
		}
		
		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc a replay subject if it completes immediately", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACReplaySubject *subject __attribute__((objc_precise_lifetime)) = [RACReplaySubject subject];
			[subject sendCompleted];

			[subject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];

			[subject subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(completed).will.beTruthy();

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc if the signal was created on a background queue", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[[RACScheduler scheduler] schedule:^{
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
					[subscriber sendCompleted];
					return nil;
				}];

				[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				[signal subscribeCompleted:^{
					completed = YES;
				}];
			}];
		}

		expect(completed).will.beTruthy();

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc if the signal was created on a background queue, never gets any subscribers, and the background queue gets delayed", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[[RACScheduler scheduler] schedule:^{
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
					return nil;
				}];

				[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				[NSThread sleepForTimeInterval:1];

				expect(deallocd).to.beFalsy();
			}];
		}

		// The default test timeout is 1s so we'd race to see if the queue delay
		// or default timeout happens first. To avoid that, just bump the
		// timeout slightly for this test.
		NSTimeInterval originalTestTimeout = Expecta.asynchronousTestTimeout;
		Expecta.asynchronousTestTimeout = 1.1f;
		expect(deallocd).will.beTruthy();
		Expecta.asynchronousTestTimeout = originalTestTimeout;
	});

	it(@"should retain signals when subscribing", ^{
		__block BOOL deallocd = NO;

		RACDisposable *disposable;
		@autoreleasepool {
			@autoreleasepool {
				@autoreleasepool {
					RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
						return nil;
					}];
					
					[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
						deallocd = YES;
					}]];
					
					disposable = [signal subscribeCompleted:^{}];
				}
				
				// Spin the run loop to account for RAC magic that retains the
				// signal for a single iteration.
				[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
			}
			
			expect(deallocd).to.beFalsy();
			
			[disposable dispose];
		}
		expect(deallocd).will.beTruthy();
	});

	it(@"should retain intermediate signals when subscribing", ^{
		RACSubject *subject = [RACSubject subject];
		expect(subject).notTo.beNil();

		__block BOOL gotNext = NO;
		__block BOOL completed = NO;

		RACDisposable *disposable;

		@autoreleasepool {
			@autoreleasepool {
				RACSignal *intermediateSignal = [subject doNext:^(id _) {
					gotNext = YES;
				}];

				expect(intermediateSignal).notTo.beNil();

				disposable = [intermediateSignal subscribeCompleted:^{
					completed = YES;
				}];
			}

			// Spin the run loop to account for RAC magic that retains the
			// signal for a single iteration.
			[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
		}

		[subject sendNext:@5];
		expect(gotNext).to.beTruthy();

		[subject sendCompleted];
		expect(completed).to.beTruthy();
		
		[disposable dispose];
	});
});

describe(@"-merge:", ^{
	__block RACSubject *sub1;
	__block RACSubject *sub2;
	__block RACSignal *merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [sub1 merge:sub2];
	});

	it(@"should send all values from both signals", ^{
		NSMutableArray *values = [NSMutableArray array];
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub1 sendNext:@4];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send an error if one occurs", ^{
		__block NSError *errorReceived;
		[merged subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[sub1 sendError:RACSignalTestError];
		expect(errorReceived).to.equal(RACSignalTestError);
	});

	it(@"should complete only after both signals complete", ^{
		NSMutableArray *values = [NSMutableArray array];
		__block BOOL completed = NO;
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub2 sendCompleted];
		expect(completed).to.beFalsy();

		[sub1 sendNext:@4];
		[sub1 sendCompleted];
		expect(completed).to.beTruthy();

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete only after both signals complete for any number of subscribers", ^{
		__block BOOL completed1 = NO;
		__block BOOL completed2 = NO;
		[merged subscribeCompleted:^{
			completed1 = YES;
		}];

		[merged subscribeCompleted:^{
			completed2 = YES;
		}];

		expect(completed1).to.beFalsy();
		expect(completed2).to.beFalsy();

		[sub1 sendCompleted];
		[sub2 sendCompleted];
		expect(completed1).to.beTruthy();
		expect(completed2).to.beTruthy();
	});
});

describe(@"+merge:", ^{
	__block RACSubject *sub1;
	__block RACSubject *sub2;
	__block RACSignal *merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [RACSignal merge:@[ sub1, sub2 ].objectEnumerator];
	});

	it(@"should send all values from both signals", ^{
		NSMutableArray *values = [NSMutableArray array];
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub1 sendNext:@4];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send an error if one occurs", ^{
		__block NSError *errorReceived;
		[merged subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[sub1 sendError:RACSignalTestError];
		expect(errorReceived).to.equal(RACSignalTestError);
	});

	it(@"should complete only after both signals complete", ^{
		NSMutableArray *values = [NSMutableArray array];
		__block BOOL completed = NO;
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub2 sendCompleted];
		expect(completed).to.beFalsy();

		[sub1 sendNext:@4];
		[sub1 sendCompleted];
		expect(completed).to.beTruthy();

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete immediately when not given any signals", ^{
		RACSignal *signal = [RACSignal merge:@[].objectEnumerator];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});

	it(@"should complete only after both signals complete for any number of subscribers", ^{
		__block BOOL completed1 = NO;
		__block BOOL completed2 = NO;
		[merged subscribeCompleted:^{
			completed1 = YES;
		}];

		[merged subscribeCompleted:^{
			completed2 = YES;
		}];

		expect(completed1).to.beFalsy();
		expect(completed2).to.beFalsy();

		[sub1 sendCompleted];
		[sub2 sendCompleted];
		expect(completed1).to.beTruthy();
		expect(completed2).to.beTruthy();
	});
});

describe(@"-flatten:", ^{
	__block BOOL subscribedTo1 = NO;
	__block BOOL subscribedTo2 = NO;
	__block BOOL subscribedTo3 = NO;
	__block RACSignal *sub1;
	__block RACSignal *sub2;
	__block RACSignal *sub3;
	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;
	__block RACSubject *signalsSubject;
	__block NSMutableArray *values;
	
	beforeEach(^{
		subscribedTo1 = NO;
		subject1 = [RACSubject subject];
		sub1 = [RACSignal defer:^{
			subscribedTo1 = YES;
			return subject1;
		}];

		subscribedTo2 = NO;
		subject2 = [RACSubject subject];
		sub2 = [RACSignal defer:^{
			subscribedTo2 = YES;
			return subject2;
		}];

		subscribedTo3 = NO;
		subject3 = [RACSubject subject];
		sub3 = [RACSignal defer:^{
			subscribedTo3 = YES;
			return subject3;
		}];

		signalsSubject = [RACSubject subject];

		values = [NSMutableArray array];
	});

	describe(@"when its max is 0", ^{
		it(@"should merge all the signals concurrently", ^{
			[[signalsSubject flatten:0] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribedTo1).to.beFalsy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[signalsSubject sendNext:sub1];
			[signalsSubject sendNext:sub2];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendNext:@1];

			[signalsSubject sendNext:sub3];
			
			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beTruthy();

			[subject1 sendCompleted];

			[subject2 sendNext:@2];
			[subject2 sendCompleted];

			[subject3 sendNext:@3];
			[subject3 sendCompleted];

			NSArray *expected = @[ @1, @2, @3 ];
			expect(values).to.equal(expected);
		});

		itShouldBehaveLike(RACSignalMergeConcurrentCompletionExampleGroup, @{ RACSignalMaxConcurrent: @0 });
	});

	describe(@"when its max is > 0", ^{
		it(@"should merge only the given number at a time", ^{
			[[signalsSubject flatten:1] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribedTo1).to.beFalsy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[signalsSubject sendNext:sub1];
			[signalsSubject sendNext:sub2];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendNext:@1];

			[signalsSubject sendNext:sub3];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[signalsSubject sendCompleted];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendCompleted];

			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beFalsy();

			[subject2 sendNext:@2];
			[subject2 sendCompleted];

			expect(subscribedTo3).to.beTruthy();

			[subject3 sendNext:@3];
			[subject3 sendCompleted];

			NSArray *expected = @[ @1, @2, @3 ];
			expect(values).to.equal(expected);
		});

		itShouldBehaveLike(RACSignalMergeConcurrentCompletionExampleGroup, @{ RACSignalMaxConcurrent: @1 });
	});

	it(@"shouldn't create a retain cycle", ^{
		__block BOOL subjectDeallocd = NO;
		__block BOOL signalDeallocd = NO;
		@autoreleasepool {
			RACSubject *subject __attribute__((objc_precise_lifetime)) = [RACSubject subject];
			[subject.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				subjectDeallocd = YES;
			}]];

			RACSignal *signal __attribute__((objc_precise_lifetime)) = [subject flatten];
			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocd = YES;
			}]];

			[signal subscribeCompleted:^{}];

			[subject sendCompleted];
		}

		expect(subjectDeallocd).will.beTruthy();
		expect(signalDeallocd).will.beTruthy();
	});

	it(@"should not crash when disposing while subscribing", ^{
		RACDisposable *disposable = [[signalsSubject flatten:0] subscribeCompleted:^{
		}];

		[signalsSubject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[disposable dispose];
			[subscriber sendCompleted];
			return nil;
		}]];

		[signalsSubject sendCompleted];
	});

	it(@"should dispose after last synchronous signal subscription and should not crash", ^{

		RACSignal *flattened = [signalsSubject flatten:1];
		RACDisposable *flattenDisposable = [flattened subscribeCompleted:^{}];

		RACSignal *syncSignal = [RACSignal createSignal:^ RACDisposable *(id<RACSubscriber> subscriber) {
			expect(flattenDisposable.disposed).to.beFalsy();
			[subscriber sendCompleted];
			expect(flattenDisposable.disposed).to.beTruthy();
			return nil;
		}];

		RACSignal *asyncSignal = [sub1 delay:0];

		[signalsSubject sendNext:asyncSignal];
		[signalsSubject sendNext:syncSignal];

		[signalsSubject sendCompleted];

		[subject1 sendCompleted];

		expect(flattenDisposable.disposed).will.beTruthy();
	});

	it(@"should not crash when disposed because of takeUntil:", ^{
		for (int i = 0; i < 100; i++) {
			RACSubject *flattenedReceiver = [RACSubject subject];
			RACSignal *done = [flattenedReceiver map:^(NSNumber *n) {
				return @(n.integerValue == 1);
			}];

			RACSignal *flattened = [signalsSubject flatten:1];

			RACDisposable *flattenDisposable = [[flattened takeUntil:[done ignore:@NO]] subscribe:flattenedReceiver];

			RACSignal *syncSignal = [RACSignal createSignal:^ RACDisposable *(id<RACSubscriber> subscriber) {
				expect(flattenDisposable.disposed).to.beFalsy();
				[subscriber sendNext:@1];
				expect(flattenDisposable.disposed).to.beTruthy();
				[subscriber sendCompleted];
				return nil;
			}];

			RACSignal *asyncSignal = [sub1 delay:0];
			[subject1 sendNext:@0];

			[signalsSubject sendNext:asyncSignal];
			[signalsSubject sendNext:syncSignal];
			[signalsSubject sendCompleted];

			[subject1 sendCompleted];

			expect(flattenDisposable.disposed).will.beTruthy();
		}
	});
});

describe(@"-switchToLatest", ^{
	__block RACSubject *subject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		subject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		[[subject switchToLatest] subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should send values from the most recent signal", ^{
		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			return nil;
		}]];

		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@3];
			[subscriber sendNext:@4];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send errors from the most recent signal", ^{
		[subject sendNext:[RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return nil;
		}]];

		expect(lastError).notTo.beNil();
	});

	it(@"should not send completed if only the switching signal completes", ^{
		[subject sendNext:RACSignal.never];

		expect(completed).to.beFalsy();

		[subject sendCompleted];
		expect(completed).to.beFalsy();
	});
	
	it(@"should send completed when the switching signal completes and the last sent signal does", ^{
		[subject sendNext:RACSignal.empty];
		
		expect(completed).to.beFalsy();
		
		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should accept nil signals", ^{
		[subject sendNext:nil];
		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2 ];
		expect(values).to.equal(expected);
	});

	it(@"should return a cold signal", ^{
		__block NSUInteger subscriptions = 0;
		RACSignal *signalOfSignals = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			subscriptions++;
			[subscriber sendNext:[RACSignal empty]];
			return nil;
		}];

		RACSignal *switched = [signalOfSignals switchToLatest];

		[[switched publish] connect];
		expect(subscriptions).to.equal(1);

		[[switched publish] connect];
		expect(subscriptions).to.equal(2);
	});
});

describe(@"+switch:cases:default:", ^{
	__block RACSubject *keySubject;

	__block RACSubject *subjectZero;
	__block RACSubject *subjectOne;
	__block RACSubject *subjectTwo;

	__block RACSubject *defaultSubject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		keySubject = [RACSubject subject];

		subjectZero = [RACSubject subject];
		subjectOne = [RACSubject subject];
		subjectTwo = [RACSubject subject];

		defaultSubject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;
	});

	describe(@"switching between values with a default", ^{
		__block RACSignal *switchSignal;

		beforeEach(^{
			switchSignal = [RACSignal switch:keySubject cases:@{
				@0: subjectZero,
				@1: subjectOne,
				@2: subjectTwo,
			} default:[RACSignal never]];

			[switchSignal subscribeNext:^(id x) {
				expect(lastError).to.beNil();
				expect(completed).to.beFalsy();

				[values addObject:x];
			} error:^(NSError *error) {
				expect(lastError).to.beNil();
				expect(completed).to.beFalsy();

				lastError = error;
			} completed:^{
				expect(lastError).to.beNil();
				expect(completed).to.beFalsy();

				completed = YES;
			}];
		});

		it(@"should not send any values before a key is sent", ^{
			[subjectZero sendNext:RACUnit.defaultUnit];
			[subjectOne sendNext:RACUnit.defaultUnit];
			[subjectTwo sendNext:RACUnit.defaultUnit];

			expect(values).to.equal(@[]);
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();
		});

		it(@"should send events based on the latest key", ^{
			[keySubject sendNext:@0];

			[subjectZero sendNext:@"zero"];
			[subjectZero sendNext:@"zero"];
			[subjectOne sendNext:@"one"];
			[subjectTwo sendNext:@"two"];

			NSArray *expected = @[ @"zero", @"zero" ];
			expect(values).to.equal(expected);

			[keySubject sendNext:@1];

			[subjectZero sendNext:@"zero"];
			[subjectOne sendNext:@"one"];
			[subjectTwo sendNext:@"two"];

			expected = @[ @"zero", @"zero", @"one" ];
			expect(values).to.equal(expected);

			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[keySubject sendNext:@2];

			[subjectZero sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			[subjectOne sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			expect(lastError).to.beNil();

			[subjectTwo sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			expect(lastError).notTo.beNil();
		});

		it(@"should not send completed when only the key signal completes", ^{
			[keySubject sendNext:@0];
			[subjectZero sendNext:@"zero"];
			[keySubject sendCompleted];

			expect(values).to.equal(@[ @"zero" ]);
			expect(completed).to.beFalsy();
		});

		it(@"should send completed when the key signal and the latest sent signal complete", ^{
			[keySubject sendNext:@0];
			[subjectZero sendNext:@"zero"];
			[keySubject sendCompleted];
			[subjectZero sendCompleted];

			expect(values).to.equal(@[ @"zero" ]);
			expect(completed).to.beTruthy();
		});
	});

	it(@"should use the default signal if key that was sent does not have an associated signal", ^{
		[[RACSignal
			switch:keySubject
			cases:@{
				@0: subjectZero,
				@1: subjectOne,
			}
			default:defaultSubject]
			subscribeNext:^(id x) {
				[values addObject:x];
			}];

		[keySubject sendNext:@"not a valid key"];
		[defaultSubject sendNext:@"default"];

		expect(values).to.equal(@[ @"default" ]);

		[keySubject sendNext:nil];
		[defaultSubject sendNext:@"default"];

		expect(values).to.equal((@[ @"default", @"default" ]));
	});

	it(@"should send an error if key that was sent does not have an associated signal and there's no default", ^{
		[[RACSignal
			switch:keySubject
			cases:@{
				@0: subjectZero,
				@1: subjectOne,
			}
			default:nil]
			subscribeNext:^(id x) {
				[values addObject:x];
			} error:^(NSError *error) {
				lastError = error;
			}];

		[keySubject sendNext:@0];
		[subjectZero sendNext:@"zero"];

		expect(values).to.equal(@[ @"zero" ]);
		expect(lastError).to.beNil();

		[keySubject sendNext:nil];

		expect(values).to.equal(@[ @"zero" ]);
		expect(lastError).notTo.beNil();
		expect(lastError.domain).to.equal(RACSignalErrorDomain);
		expect(lastError.code).to.equal(RACSignalErrorNoMatchingCase);
	});

	it(@"should match RACTupleNil case when a nil value is sent", ^{
		[[RACSignal
			switch:keySubject
			cases:@{
				RACTupleNil.tupleNil: subjectZero,
			}
			default:defaultSubject]
			subscribeNext:^(id x) {
				[values addObject:x];
			}];

		[keySubject sendNext:nil];
		[subjectZero sendNext:@"zero"];
		expect(values).to.equal(@[ @"zero" ]);
	});
});

describe(@"+if:then:else", ^{
	__block RACSubject *boolSubject;
	__block RACSubject *trueSubject;
	__block RACSubject *falseSubject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		boolSubject = [RACSubject subject];
		trueSubject = [RACSubject subject];
		falseSubject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		[[RACSignal if:boolSubject then:trueSubject else:falseSubject] subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should not send any values before a boolean is sent", ^{
		[trueSubject sendNext:RACUnit.defaultUnit];
		[falseSubject sendNext:RACUnit.defaultUnit];

		expect(values).to.equal(@[]);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();
	});

	it(@"should send events based on the latest boolean", ^{
		[boolSubject sendNext:@YES];

		[trueSubject sendNext:@"foo"];
		[falseSubject sendNext:@"buzz"];
		[trueSubject sendNext:@"bar"];

		NSArray *expected = @[ @"foo", @"bar" ];
		expect(values).to.equal(expected);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[boolSubject sendNext:@NO];

		[trueSubject sendNext:@"baz"];
		[falseSubject sendNext:@"buzz"];
		[trueSubject sendNext:@"barfoo"];

		expected = @[ @"foo", @"bar", @"buzz" ];
		expect(values).to.equal(expected);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[trueSubject sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).to.beNil();

		[falseSubject sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).notTo.beNil();
	});

	it(@"should not send completed when only the BOOL signal completes", ^{
		[boolSubject sendNext:@YES];
		[trueSubject sendNext:@"foo"];
		[boolSubject sendCompleted];
		
		expect(values).to.equal(@[ @"foo" ]);
		expect(completed).to.beFalsy();
	});

	it(@"should send completed when the BOOL signal and the latest sent signal complete", ^{
		[boolSubject sendNext:@YES];
		[trueSubject sendNext:@"foo"];
		[trueSubject sendCompleted];
		[boolSubject sendCompleted];

		expect(values).to.equal(@[ @"foo" ]);
		expect(completed).to.beTruthy();
	});
});

describe(@"+interval:onScheduler: and +interval:onScheduler:withLeeway:", ^{
	static const NSTimeInterval interval = 0.1;
	static const NSTimeInterval leeway = 0.2;
	
	__block void (^testTimer)(RACSignal *, NSNumber *, NSNumber *) = nil;
	
	before(^{
		testTimer = [^(RACSignal *timer, NSNumber *minInterval, NSNumber *leeway) {
			__block NSUInteger nextsReceived = 0;

			NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
			[[timer take:3] subscribeNext:^(NSDate *date) {
				++nextsReceived;

				NSTimeInterval currentTime = date.timeIntervalSinceReferenceDate;

				// Uniformly distribute the expected interval for all
				// received values. We do this instead of saving a timestamp
				// because a delayed interval may cause the _next_ value to
				// send sooner than the interval.
				NSTimeInterval expectedMinInterval = minInterval.doubleValue * nextsReceived;
				NSTimeInterval expectedMaxInterval = expectedMinInterval + leeway.doubleValue * 3 + 0.05;

				expect(currentTime - startTime).beGreaterThanOrEqualTo(expectedMinInterval);
				expect(currentTime - startTime).beLessThanOrEqualTo(expectedMaxInterval);
			}];
			
			expect(nextsReceived).will.equal(3);
		} copy];
	});
	
	describe(@"+interval:onScheduler:", ^{
		it(@"should work on the main thread scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:RACScheduler.mainThreadScheduler], @(interval), @0);
		});
		
		it(@"should work on a background scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:[RACScheduler scheduler]], @(interval), @0);
		});
	});
	
	describe(@"+interval:onScheduler:withLeeway:", ^{
		it(@"should work on the main thread scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:RACScheduler.mainThreadScheduler withLeeway:leeway], @(interval), @(leeway));
		});
		
		it(@"should work on a background scheduler", ^{
			testTimer([RACSignal interval:interval onScheduler:[RACScheduler scheduler] withLeeway:leeway], @(interval), @(leeway));
		});
	});
});

describe(@"-timeout:onScheduler:", ^{
	__block RACSubject *subject;

	beforeEach(^{
		subject = [RACSubject subject];
	});

	it(@"should time out", ^{
		RACTestScheduler *scheduler = [[RACTestScheduler alloc] init];

		__block NSError *receivedError = nil;
		[[subject timeout:1 onScheduler:scheduler] subscribeError:^(NSError *e) {
			receivedError = e;
		}];

		expect(receivedError).to.beNil();

		[scheduler stepAll];
		expect(receivedError).willNot.beNil();
		expect(receivedError.domain).to.equal(RACSignalErrorDomain);
		expect(receivedError.code).to.equal(RACSignalErrorTimedOut);
	});

	it(@"should pass through events while not timed out", ^{
		__block id next = nil;
		__block BOOL completed = NO;
		[[subject timeout:1 onScheduler:RACScheduler.mainThreadScheduler] subscribeNext:^(id x) {
			next = x;
		} completed:^{
			completed = YES;
		}];

		[subject sendNext:RACUnit.defaultUnit];
		expect(next).to.equal(RACUnit.defaultUnit);

		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should not time out after disposal", ^{
		RACTestScheduler *scheduler = [[RACTestScheduler alloc] init];

		__block NSError *receivedError = nil;
		RACDisposable *disposable = [[subject timeout:1 onScheduler:scheduler] subscribeError:^(NSError *e) {
			receivedError = e;
		}];

		[disposable dispose];
		[scheduler stepAll];
		expect(receivedError).to.beNil();
	});
});

describe(@"-delay:", ^{
	__block RACSubject *subject;
	__block RACSignal *delayedSignal;

	beforeEach(^{
		subject = [RACSubject subject];
		delayedSignal = [subject delay:0];
	});

	it(@"should delay nexts", ^{
		__block id next = nil;
		[delayedSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];
		expect(next).to.beNil();
		expect(next).will.equal(@"foo");
	});

	it(@"should delay completed", ^{
		__block BOOL completed = NO;
		[delayedSignal subscribeCompleted:^{
			completed = YES;
		}];

		[subject sendCompleted];
		expect(completed).to.beFalsy();
		expect(completed).will.beTruthy();
	});

	it(@"should not delay errors", ^{
		__block NSError *error = nil;
		[delayedSignal subscribeError:^(NSError *e) {
			error = e;
		}];

		[subject sendError:RACSignalTestError];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should cancel delayed events when disposed", ^{
		__block id next = nil;
		RACDisposable *disposable = [delayedSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];

		__block BOOL done = NO;
		[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
			done = YES;
		}];

		[disposable dispose];

		expect(done).will.beTruthy();
		expect(next).to.beNil();
	});
});

describe(@"-catch:", ^{
	it(@"should subscribe to ensuing signal on error", ^{
		RACSubject *subject = [RACSubject subject];

		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal return:@41];
		}];

		__block id value = nil;
		[signal subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendError:RACSignalTestError];
		expect(value).to.equal(@41);
	});

	it(@"should prevent source error from propagating", ^{
		RACSubject *subject = [RACSubject subject];

		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal empty];
		}];

		__block BOOL errorReceived = NO;
		[signal subscribeError:^(NSError *error) {
			errorReceived = YES;
		}];

		[subject sendError:RACSignalTestError];
		expect(errorReceived).to.beFalsy();
	});

	it(@"should propagate error from ensuing signal", ^{
		RACSubject *subject = [RACSubject subject];

		NSError *secondaryError = [NSError errorWithDomain:@"bubs" code:41 userInfo:nil];
		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal error:secondaryError];
		}];

		__block NSError *errorReceived = nil;
		[signal subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[subject sendError:RACSignalTestError];
		expect(errorReceived).to.equal(secondaryError);
	});

	it(@"should dispose ensuing signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block BOOL disposed = NO;
		RACSignal *signal = [subject catch:^(NSError *error) {
			return [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
				return [RACDisposable disposableWithBlock:^{
					disposed = YES;
				}];
			}];
		}];

		RACDisposable *disposable = [signal subscribeCompleted:^{}];
		[subject sendError:RACSignalTestError];
		[disposable dispose];

		expect(disposed).will.beTruthy();
	});
});

describe(@"-try:", ^{
	__block RACSubject *subject;
	__block NSError *receivedError;
	__block NSMutableArray *nextValues;
	__block BOOL completed;
	
	beforeEach(^{
		subject = [RACSubject subject];
		nextValues = [NSMutableArray array];
		completed = NO;
		receivedError = nil;
		
		[[subject try:^(NSString *value, NSError **error) {
			if (value != nil) return YES;
			
			if (error != nil) *error = RACSignalTestError;
			
			return NO;
		}] subscribeNext:^(id x) {
			[nextValues addObject:x];
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			completed = YES;
		}];
	});
	
	it(@"should pass values while YES is returned from the tryBlock", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:@"baz"];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];
		
		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo", @"bar", @"baz", @"buzz" ];
		
		expect(receivedError).to.beNil();
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beTruthy();
	});
	
	it(@"should pass values until NO is returned from the tryBlock", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:nil];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];
		
		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo", @"bar" ];
		
		expect(receivedError).to.equal(RACSignalTestError);
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beFalsy();
	});
});

describe(@"-tryMap:", ^{
	__block RACSubject *subject;
	__block NSError *receivedError;
	__block NSMutableArray *nextValues;
	__block BOOL completed;
	
	beforeEach(^{
		subject = [RACSubject subject];
		nextValues = [NSMutableArray array];
		completed = NO;
		receivedError = nil;
		
		[[subject tryMap:^ id (NSString *value, NSError **error) {
			if (value != nil) return [NSString stringWithFormat:@"%@_a", value];
			
			if (error != nil) *error = RACSignalTestError;

			return nil;
		}] subscribeNext:^(id x) {
			[nextValues addObject:x];
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			completed = YES;
		}];
	});
	
	it(@"should map values with the mapBlock", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:@"baz"];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];

		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo_a", @"bar_a", @"baz_a", @"buzz_a" ];
		
		expect(receivedError).to.beNil();
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beTruthy();
	});
	
	it(@"should map values with the mapBlock, until the mapBlock returns nil", ^{
		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		[subject sendNext:nil];
		[subject sendNext:@"buzz"];
		[subject sendCompleted];
		
		NSArray *receivedValues = [nextValues copy];
		NSArray *expectedValues = @[ @"foo_a", @"bar_a" ];
		
		expect(receivedError).to.equal(RACSignalTestError);
		expect(receivedValues).to.equal(expectedValues);
		expect(completed).to.beFalsy();
	});
});

describe(@"throttling", ^{
	__block RACSubject *subject;

	beforeEach(^{
		subject = [RACSubject subject];
	});

	describe(@"-throttle:", ^{
		__block RACSignal *throttledSignal;

		beforeEach(^{
			throttledSignal = [subject throttle:0];
		});

		it(@"should throttle nexts", ^{
			NSMutableArray *valuesReceived = [NSMutableArray array];
			[throttledSignal subscribeNext:^(id x) {
				[valuesReceived addObject:x];
			}];

			[subject sendNext:@"foo"];
			[subject sendNext:@"bar"];
			expect(valuesReceived).to.equal(@[]);

			NSArray *expected = @[ @"bar" ];
			expect(valuesReceived).will.equal(expected);

			[subject sendNext:@"buzz"];
			expect(valuesReceived).to.equal(expected);

			expected = @[ @"bar", @"buzz" ];
			expect(valuesReceived).will.equal(expected);
		});

		it(@"should forward completed immediately", ^{
			__block BOOL completed = NO;
			[throttledSignal subscribeCompleted:^{
				completed = YES;
			}];

			[subject sendCompleted];
			expect(completed).to.beTruthy();
		});

		it(@"should forward errors immediately", ^{
			__block NSError *error = nil;
			[throttledSignal subscribeError:^(NSError *e) {
				error = e;
			}];

			[subject sendError:RACSignalTestError];
			expect(error).to.equal(RACSignalTestError);
		});

		it(@"should cancel future nexts when disposed", ^{
			__block id next = nil;
			RACDisposable *disposable = [throttledSignal subscribeNext:^(id x) {
				next = x;
			}];

			[subject sendNext:@"foo"];

			__block BOOL done = NO;
			[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
				done = YES;
			}];

			[disposable dispose];

			expect(done).will.beTruthy();
			expect(next).to.beNil();
		});
	});

	describe(@"-throttle:valuesPassingTest:", ^{
		__block RACSignal *throttledSignal;
		__block BOOL shouldThrottle;

		beforeEach(^{
			shouldThrottle = YES;

			__block id value = nil;
			throttledSignal = [[subject
				doNext:^(id x) {
					value = x;
				}]
				throttle:0 valuesPassingTest:^(id x) {
					// Make sure that we're given the latest value.
					expect(x).to.beIdenticalTo(value);

					return shouldThrottle;
				}];

			expect(throttledSignal).notTo.beNil();
		});

		describe(@"nexts", ^{
			__block NSMutableArray *valuesReceived;
			__block NSMutableArray *expected;

			beforeEach(^{
				expected = [[NSMutableArray alloc] init];
				valuesReceived = [[NSMutableArray alloc] init];

				[throttledSignal subscribeNext:^(id x) {
					[valuesReceived addObject:x];
				}];
			});

			it(@"should forward unthrottled values immediately", ^{
				shouldThrottle = NO;
				[subject sendNext:@"foo"];

				[expected addObject:@"foo"];
				expect(valuesReceived).to.equal(expected);
			});

			it(@"should delay throttled values", ^{
				[subject sendNext:@"bar"];
				expect(valuesReceived).to.equal(expected);

				[expected addObject:@"bar"];
				expect(valuesReceived).will.equal(expected);
			});

			it(@"should drop buffered values when a throttled value arrives", ^{
				[subject sendNext:@"foo"];
				[subject sendNext:@"bar"];
				[subject sendNext:@"buzz"];
				expect(valuesReceived).to.equal(expected);

				[expected addObject:@"buzz"];
				expect(valuesReceived).will.equal(expected);
			});

			it(@"should drop buffered values when an immediate value arrives", ^{
				[subject sendNext:@"foo"];
				[subject sendNext:@"bar"];

				shouldThrottle = NO;
				[subject sendNext:@"buzz"];
				[expected addObject:@"buzz"];
				expect(valuesReceived).to.equal(expected);

				// Make sure that nothing weird happens when sending another
				// throttled value.
				shouldThrottle = YES;
				[subject sendNext:@"baz"];
				expect(valuesReceived).to.equal(expected);

				[expected addObject:@"baz"];
				expect(valuesReceived).will.equal(expected);
			});

			it(@"should not be resent upon completion", ^{
				[subject sendNext:@"bar"];
				[expected addObject:@"bar"];
				expect(valuesReceived).will.equal(expected);

				[subject sendCompleted];
				expect(valuesReceived).to.equal(expected);
			});
		});

		it(@"should forward completed immediately", ^{
			__block BOOL completed = NO;
			[throttledSignal subscribeCompleted:^{
				completed = YES;
			}];

			[subject sendCompleted];
			expect(completed).to.beTruthy();
		});

		it(@"should forward errors immediately", ^{
			__block NSError *error = nil;
			[throttledSignal subscribeError:^(NSError *e) {
				error = e;
			}];

			[subject sendError:RACSignalTestError];
			expect(error).to.equal(RACSignalTestError);
		});

		it(@"should cancel future nexts when disposed", ^{
			__block id next = nil;
			RACDisposable *disposable = [throttledSignal subscribeNext:^(id x) {
				next = x;
			}];

			[subject sendNext:@"foo"];

			__block BOOL done = NO;
			[RACScheduler.mainThreadScheduler after:[NSDate date] schedule:^{
				done = YES;
			}];

			[disposable dispose];

			expect(done).will.beTruthy();
			expect(next).to.beNil();
		});
	});
});

describe(@"-then:", ^{
	it(@"should continue onto returned signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block id value = nil;
		[[subject then:^{
			return [RACSignal return:@2];
		}] subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendNext:@1];

		// The value shouldn't change until the first signal completes.
		expect(value).to.beNil();

		[subject sendCompleted];

		expect(value).to.equal(@2);
	});

	it(@"should sequence even if no next value is sent", ^{
		RACSubject *subject = [RACSubject subject];

		__block id value = nil;
		[[subject then:^{
			return [RACSignal return:RACUnit.defaultUnit];
		}] subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendCompleted];

		expect(value).to.equal(RACUnit.defaultUnit);
	});
});

describe(@"-sequence", ^{
	RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:@1];
		[subscriber sendNext:@2];
		[subscriber sendNext:@3];
		[subscriber sendNext:@4];
		[subscriber sendCompleted];
		return nil;
	}];

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: signal.sequence,
			RACSequenceExampleExpectedValues: @[ @1, @2, @3, @4 ]
		};
	});
});

it(@"should complete take: even if the original signal doesn't", ^{
	RACSignal *sendOne = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:RACUnit.defaultUnit];
		return nil;
	}];

	__block id value = nil;
	__block BOOL completed = NO;
	[[sendOne take:1] subscribeNext:^(id received) {
		value = received;
	} completed:^{
		completed = YES;
	}];

	expect(value).to.equal(RACUnit.defaultUnit);
	expect(completed).to.beTruthy();
});

describe(@"+zip:", ^{
	__block RACSubject *subject1 = nil;
	__block RACSubject *subject2 = nil;
	__block BOOL hasSentError = NO;
	__block BOOL hasSentCompleted = NO;
	__block RACDisposable *disposable = nil;
	__block void (^send2NextAndErrorTo1)(void) = nil;
	__block void (^send3NextAndErrorTo1)(void) = nil;
	__block void (^send2NextAndCompletedTo2)(void) = nil;
	__block void (^send3NextAndCompletedTo2)(void) = nil;
	
	before(^{
		send2NextAndErrorTo1 = [^{
			[subject1 sendNext:@1];
			[subject1 sendNext:@2];
			[subject1 sendError:RACSignalTestError];
		} copy];
		send3NextAndErrorTo1 = [^{
			[subject1 sendNext:@1];
			[subject1 sendNext:@2];
			[subject1 sendNext:@3];
			[subject1 sendError:RACSignalTestError];
		} copy];
		send2NextAndCompletedTo2 = [^{
			[subject2 sendNext:@1];
			[subject2 sendNext:@2];
			[subject2 sendCompleted];
		} copy];
		send3NextAndCompletedTo2 = [^{
			[subject2 sendNext:@1];
			[subject2 sendNext:@2];
			[subject2 sendNext:@3];
			[subject2 sendCompleted];
		} copy];
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		hasSentError = NO;
		hasSentCompleted = NO;
		disposable = [[RACSignal zip:@[ subject1, subject2 ]] subscribeError:^(NSError *error) {
			hasSentError = YES;
		} completed:^{
			hasSentCompleted = YES;
		}];
	});
	
	after(^{
		[disposable dispose];
	});
	
	it(@"should complete as soon as no new zipped values are possible", ^{
		[subject1 sendNext:@1];
		[subject2 sendNext:@1];
		expect(hasSentCompleted).to.beFalsy();
		
		[subject1 sendNext:@2];
		[subject1 sendCompleted];
		expect(hasSentCompleted).to.beFalsy();
		
		[subject2 sendNext:@2];
		expect(hasSentCompleted).to.beTruthy();
	});
	
	it(@"outcome should not be dependent on order of signals", ^{
		[subject2 sendCompleted];
		expect(hasSentCompleted).to.beTruthy();
	});
    
	it(@"should forward errors sent earlier than (time-wise) and before (position-wise) a complete", ^{
		send2NextAndErrorTo1();
		send3NextAndCompletedTo2();
		expect(hasSentError).to.beTruthy();
		expect(hasSentCompleted).to.beFalsy();
	});
	
	it(@"should forward errors sent earlier than (time-wise) and after (position-wise) a complete", ^{
		send3NextAndErrorTo1();
		send2NextAndCompletedTo2();
		expect(hasSentError).to.beTruthy();
		expect(hasSentCompleted).to.beFalsy();
	});
	
	it(@"should forward errors sent later than (time-wise) and before (position-wise) a complete", ^{
		send3NextAndCompletedTo2();
		send2NextAndErrorTo1();
		expect(hasSentError).to.beTruthy();
		expect(hasSentCompleted).to.beFalsy();
	});
	
	it(@"should ignore errors sent later than (time-wise) and after (position-wise) a complete", ^{
		send2NextAndCompletedTo2();
		send3NextAndErrorTo1();
		expect(hasSentError).to.beFalsy();
		expect(hasSentCompleted).to.beTruthy();
	});
	
	it(@"should handle signals sending values unevenly", ^{
		__block NSError *receivedError = nil;
		__block BOOL hasCompleted = NO;
		
		RACSubject *a = [RACSubject subject];
		RACSubject *b = [RACSubject subject];
		RACSubject *c = [RACSubject subject];
		
		NSMutableArray *receivedValues = NSMutableArray.array;
		NSArray *expectedValues = nil;
		
		[[RACSignal zip:@[ a, b, c ] reduce:^(NSNumber *a, NSNumber *b, NSNumber *c) {
			return [NSString stringWithFormat:@"%@%@%@", a, b, c];
		}] subscribeNext:^(id x) {
			[receivedValues addObject:x];
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			hasCompleted = YES;
		}];
		
		[a sendNext:@1];
		[a sendNext:@2];
		[a sendNext:@3];
		
		[b sendNext:@1];
		
		[c sendNext:@1];
		[c sendNext:@2];
		
		// a: [===......]
		// b: [=........]
		// c: [==.......]
		
		expectedValues = @[ @"111" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.beNil();
		expect(hasCompleted).to.beFalsy();
		
		[b sendNext:@2];
		[b sendNext:@3];
		[b sendNext:@4];
		[b sendCompleted];
		
		// a: [===......]
		// b: [====C....]
		// c: [==.......]
		
		expectedValues = @[ @"111", @"222" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.beNil();
		expect(hasCompleted).to.beFalsy();
		
		[c sendNext:@3];
		[c sendNext:@4];
		[c sendNext:@5];
		[c sendError:RACSignalTestError];
		
		// a: [===......]
		// b: [====C....]
		// c: [=====E...]
		
		expectedValues = @[ @"111", @"222", @"333" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.equal(RACSignalTestError);
		expect(hasCompleted).to.beFalsy();
		
		[a sendNext:@4];
		[a sendNext:@5];
		[a sendNext:@6];
		[a sendNext:@7];
		
		// a: [=======..]
		// b: [====C....]
		// c: [=====E...]
		
		expectedValues = @[ @"111", @"222", @"333" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.equal(RACSignalTestError);
		expect(hasCompleted).to.beFalsy();
	});
	
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			++counter;
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];
		RACSignal *combined = [RACSignal zip:@[ sideEffectingSignal, sideEffectingSignal ] reduce:^ NSString * (id x, id y) {
			return [NSString stringWithFormat:@"%@%@", x, y];
		}];
		NSMutableArray *receivedValues = NSMutableArray.array;
		
		expect(counter).to.equal(0);
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(2);
		expect(receivedValues).to.equal(@[ @"11" ]);
	});
});

describe(@"-sample:", ^{
	it(@"should send the latest value when the sampler signal fires", ^{
		RACSubject *subject = [RACSubject subject];
		RACSubject *sampleSubject = [RACSubject subject];
		RACSignal *sampled = [subject sample:sampleSubject];
		NSMutableArray *values = [NSMutableArray array];
		[sampled subscribeNext:^(id x) {
			[values addObject:x];
		}];
		
		[sampleSubject sendNext:RACUnit.defaultUnit];
		expect(values).to.equal(@[]);
		
		[subject sendNext:@1];
		[subject sendNext:@2];
		expect(values).to.equal(@[]);

		[sampleSubject sendNext:RACUnit.defaultUnit];
		NSArray *expected = @[ @2 ];
		expect(values).to.equal(expected);

		[subject sendNext:@3];
		expect(values).to.equal(expected);

		[sampleSubject sendNext:RACUnit.defaultUnit];
		expected = @[ @2, @3 ];
		expect(values).to.equal(expected);

		[sampleSubject sendNext:RACUnit.defaultUnit];
		expected = @[ @2, @3, @3 ];
		expect(values).to.equal(expected);
	});
});

describe(@"-collect", ^{
	__block RACSubject *subject;
	__block RACSignal *collected;

	__block id value;
	__block BOOL hasCompleted;

	beforeEach(^{
		subject = [RACSubject subject];
		collected = [subject collect];
		
		value = nil;
		hasCompleted = NO;
		
		[collected subscribeNext:^(id x) {
			value = x;
		} completed:^{
			hasCompleted = YES;
		}];
	});
	
	it(@"should send a single array when the original signal completes", ^{
		NSArray *expected = @[ @1, @2, @3 ];

		[subject sendNext:@1];
		[subject sendNext:@2];
		[subject sendNext:@3];
		expect(value).to.beNil();

		[subject sendCompleted];
		expect(value).to.equal(expected);
		expect(hasCompleted).to.beTruthy();
	});

	it(@"should add NSNull to an array for nil values", ^{
		NSArray *expected = @[ NSNull.null, @1, NSNull.null ];
		
		[subject sendNext:nil];
		[subject sendNext:@1];
		[subject sendNext:nil];
		expect(value).to.beNil();
		
		[subject sendCompleted];
		expect(value).to.equal(expected);
		expect(hasCompleted).to.beTruthy();
	});
});

describe(@"-bufferWithTime:", ^{
	__block RACTestScheduler *scheduler;

	__block RACSubject *input;
	__block RACSignal *bufferedInput;
	__block RACTuple *latestValue;

	beforeEach(^{
		scheduler = [[RACTestScheduler alloc] init];

		input = [RACSubject subject];
		bufferedInput = [input bufferWithTime:1 onScheduler:scheduler];
		latestValue = nil;

		[bufferedInput subscribeNext:^(RACTuple *x) {
			latestValue = x;
		}];
	});

	it(@"should buffer nexts", ^{
		[input sendNext:@1];
		[input sendNext:@2];

		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1, @2));
		
		[input sendNext:@3];
		[input sendNext:@4];

		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@3, @4));
	});

	it(@"should not perform buffering until a value is sent", ^{
		[input sendNext:@1];
		[input sendNext:@2];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1, @2));

		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1, @2));
		
		[input sendNext:@3];
		[input sendNext:@4];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@3, @4));
	});

	it(@"should flush any buffered nexts upon completion", ^{
		[input sendNext:@1];
		[input sendCompleted];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(@1));
	});

	it(@"should support NSNull values", ^{
		[input sendNext:NSNull.null];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(NSNull.null));
	});

	it(@"should buffer nil values", ^{
		[input sendNext:nil];
		[scheduler stepAll];
		expect(latestValue).to.equal(RACTuplePack(nil));
	});
});

describe(@"-concat", ^{
	__block RACSubject *subject;

	__block RACSignal *oneSignal;
	__block RACSignal *twoSignal;
	__block RACSignal *threeSignal;

	__block RACSignal *errorSignal;
	__block RACSignal *completedSignal;

	beforeEach(^{
		subject = [RACReplaySubject subject];

		oneSignal = [RACSignal return:@1];
		twoSignal = [RACSignal return:@2];
		threeSignal = [RACSignal return:@3];

		errorSignal = [RACSignal error:RACSignalTestError];
		completedSignal = RACSignal.empty;
	});

	it(@"should concatenate the values of inner signals", ^{
		[subject sendNext:oneSignal];
		[subject sendNext:twoSignal];
		[subject sendNext:completedSignal];
		[subject sendNext:threeSignal];

		NSMutableArray *values = [NSMutableArray array];
		[[subject concat] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		NSArray *expected = @[ @1, @2, @3 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete only after all signals complete", ^{
		RACReplaySubject *valuesSubject = [RACReplaySubject subject];

		[subject sendNext:valuesSubject];
		[subject sendCompleted];

		[valuesSubject sendNext:@1];
		[valuesSubject sendNext:@2];
		[valuesSubject sendCompleted];

		NSArray *expected = @[ @1, @2 ];
		expect([[subject concat] toArray]).to.equal(expected);
	});

	it(@"should pass through errors", ^{
		[subject sendNext:errorSignal];
		
		NSError *error = nil;
		[[subject concat] firstOrDefault:nil success:NULL error:&error];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should concat signals sent later", ^{
		[subject sendNext:oneSignal];

		NSMutableArray *values = [NSMutableArray array];
		[[subject concat] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		NSArray *expected = @[ @1 ];
		expect(values).to.equal(expected);

		[subject sendNext:[twoSignal delay:0]];

		expected = @[ @1, @2 ];
		expect(values).will.equal(expected);

		[subject sendNext:threeSignal];

		expected = @[ @1, @2, @3 ];
		expect(values).to.equal(expected);
	});

	it(@"should dispose the current signal", ^{
		__block BOOL disposed = NO;
		RACSignal *innerSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				disposed = YES;
			}];
		}];

		RACDisposable *concatDisposable = [[subject concat] subscribeCompleted:^{}];
		
		[subject sendNext:innerSignal];
		expect(disposed).notTo.beTruthy();

		[concatDisposable dispose];
		expect(disposed).to.beTruthy();
	});

	it(@"should dispose later signals", ^{
		__block BOOL disposed = NO;
		RACSignal *laterSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				disposed = YES;
			}];
		}];

		RACSubject *firstSignal = [RACSubject subject];
		RACSignal *outerSignal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:firstSignal];
			[subscriber sendNext:laterSignal];
			return nil;
		}];

		RACDisposable *concatDisposable = [[outerSignal concat] subscribeCompleted:^{}];

		[firstSignal sendCompleted];
		expect(disposed).notTo.beTruthy();

		[concatDisposable dispose];
		expect(disposed).to.beTruthy();
	});
});

describe(@"-initially:", ^{
	__block RACSubject *subject;

	__block NSUInteger initiallyInvokedCount;
	__block RACSignal *signal;

	beforeEach(^{
		subject = [RACSubject subject];

		initiallyInvokedCount = 0;
		signal = [subject initially:^{
			++initiallyInvokedCount;
		}];
	});

	it(@"should not run without a subscription", ^{
		[subject sendCompleted];
		expect(initiallyInvokedCount).to.equal(0);
	});

	it(@"should run on subscription", ^{
		[signal subscribe:[RACSubscriber new]];
		expect(initiallyInvokedCount).to.equal(1);
	});

	it(@"should re-run for each subscription", ^{
		[signal subscribe:[RACSubscriber new]];
		[signal subscribe:[RACSubscriber new]];
		expect(initiallyInvokedCount).to.equal(2);
	});
});

describe(@"-finally:", ^{
	__block RACSubject *subject;

	__block BOOL finallyInvoked;
	__block RACSignal *signal;

	beforeEach(^{
		subject = [RACSubject subject];
		
		finallyInvoked = NO;
		signal = [subject finally:^{
			finallyInvoked = YES;
		}];
	});

	it(@"should not run finally without a subscription", ^{
		[subject sendCompleted];
		expect(finallyInvoked).to.beFalsy();
	});

	describe(@"with a subscription", ^{
		__block RACDisposable *disposable;

		beforeEach(^{
			disposable = [signal subscribeCompleted:^{}];
		});
		
		afterEach(^{
			[disposable dispose];
		});

		it(@"should not run finally upon next", ^{
			[subject sendNext:RACUnit.defaultUnit];
			expect(finallyInvoked).to.beFalsy();
		});

		it(@"should run finally upon completed", ^{
			[subject sendCompleted];
			expect(finallyInvoked).to.beTruthy();
		});

		it(@"should run finally upon error", ^{
			[subject sendError:nil];
			expect(finallyInvoked).to.beTruthy();
		});
	});
});

describe(@"-ignoreValues", ^{
	__block RACSubject *subject;

	__block BOOL gotNext;
	__block BOOL gotCompleted;
	__block NSError *receivedError;

	beforeEach(^{
		subject = [RACSubject subject];

		gotNext = NO;
		gotCompleted = NO;
		receivedError = nil;

		[[subject ignoreValues] subscribeNext:^(id _) {
			gotNext = YES;
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			gotCompleted = YES;
		}];
	});

	it(@"should skip nexts and pass through completed", ^{
		[subject sendNext:RACUnit.defaultUnit];
		[subject sendCompleted];

		expect(gotNext).to.beFalsy();
		expect(gotCompleted).to.beTruthy();
		expect(receivedError).to.beNil();
	});

	it(@"should skip nexts and pass through errors", ^{
		[subject sendNext:RACUnit.defaultUnit];
		[subject sendError:RACSignalTestError];

		expect(gotNext).to.beFalsy();
		expect(gotCompleted).to.beFalsy();
		expect(receivedError).to.equal(RACSignalTestError);
	});
});

describe(@"-materialize", ^{
	it(@"should convert nexts and completed into RACEvents", ^{
		NSArray *events = [[[RACSignal return:RACUnit.defaultUnit] materialize] toArray];
		NSArray *expected = @[
			[RACEvent eventWithValue:RACUnit.defaultUnit],
			RACEvent.completedEvent
		];

		expect(events).to.equal(expected);
	});

	it(@"should convert errors into RACEvents and complete", ^{
		NSArray *events = [[[RACSignal error:RACSignalTestError] materialize] toArray];
		NSArray *expected = @[ [RACEvent eventWithError:RACSignalTestError] ];
		expect(events).to.equal(expected);
	});
});

describe(@"-dematerialize", ^{
	it(@"should convert nexts from RACEvents", ^{
		RACSignal *events = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendNext:[RACEvent eventWithValue:@2]];
			[subscriber sendCompleted];
			return nil;
		}];

		NSArray *expected = @[ @1, @2 ];
		expect([[events dematerialize] toArray]).to.equal(expected);
	});

	it(@"should convert completed from a RACEvent", ^{
		RACSignal *events = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendNext:RACEvent.completedEvent];
			[subscriber sendNext:[RACEvent eventWithValue:@2]];
			[subscriber sendCompleted];
			return nil;
		}];

		NSArray *expected = @[ @1 ];
		expect([[events dematerialize] toArray]).to.equal(expected);
	});

	it(@"should convert error from a RACEvent", ^{
		RACSignal *events = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithError:RACSignalTestError]];
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendCompleted];
			return nil;
		}];

		__block NSError *error = nil;
		expect([[events dematerialize] firstOrDefault:nil success:NULL error:&error]).to.beNil();
		expect(error).to.equal(RACSignalTestError);
	});
});

describe(@"-not", ^{
	it(@"should invert every BOOL sent", ^{
		RACSubject *subject = [RACReplaySubject subject];
		[subject sendNext:@NO];
		[subject sendNext:@YES];
		[subject sendCompleted];
		NSArray *results = [[subject not] toArray];
		NSArray *expected = @[ @YES, @NO ];
		expect(results).to.equal(expected);
	});
});

describe(@"-and", ^{
	it(@"should return YES if all YES values are sent", ^{
		RACSubject *subject = [RACReplaySubject subject];
		
		[subject sendNext:RACTuplePack(@YES, @NO, @YES)];
		[subject sendNext:RACTuplePack(@NO, @NO, @NO)];
		[subject sendNext:RACTuplePack(@YES, @YES, @YES)];
		[subject sendCompleted];
		
		NSArray *results = [[subject and] toArray];
		NSArray *expected = @[ @NO, @NO, @YES ];
		
		expect(results).to.equal(expected);
	});
});

describe(@"-or", ^{
	it(@"should return YES for any YES values sent", ^{
		RACSubject *subject = [RACReplaySubject subject];
		
		[subject sendNext:RACTuplePack(@YES, @NO, @YES)];
		[subject sendNext:RACTuplePack(@NO, @NO, @NO)];
		[subject sendCompleted];
		
		NSArray *results = [[subject or] toArray];
		NSArray *expected = @[ @YES, @NO ];
		
		expect(results).to.equal(expected);
	});
});

describe(@"-groupBy:", ^{
	it(@"should send completed to all grouped signals.", ^{
		RACSubject *subject = [RACReplaySubject subject];

		__block NSUInteger groupedSignalCount = 0;
		__block NSUInteger completedGroupedSignalCount = 0;
		[[subject groupBy:^(NSNumber *number) {
			return @(floorf(number.floatValue));
		}] subscribeNext:^(RACGroupedSignal *groupedSignal) {
			++groupedSignalCount;

			[groupedSignal subscribeCompleted:^{
				++completedGroupedSignalCount;
			}];
		}];

		[subject sendNext:@1];
		[subject sendNext:@2];
		[subject sendCompleted];

		expect(completedGroupedSignalCount).to.equal(groupedSignalCount);
	});

	it(@"should send error to all grouped signals.", ^{
		RACSubject *subject = [RACReplaySubject subject];

		__block NSUInteger groupedSignalCount = 0;
		__block NSUInteger erroneousGroupedSignalCount = 0;
		[[subject groupBy:^(NSNumber *number) {
			return @(floorf(number.floatValue));
		}] subscribeNext:^(RACGroupedSignal *groupedSignal) {
			++groupedSignalCount;

			[groupedSignal subscribeError:^(NSError *error) {
				++erroneousGroupedSignalCount;

				expect(error.domain).to.equal(@"TestDomain");
				expect(error.code).to.equal(123);
			}];
		}];

		[subject sendNext:@1];
		[subject sendNext:@2];
		[subject sendError:[NSError errorWithDomain:@"TestDomain" code:123 userInfo:nil]];

		expect(erroneousGroupedSignalCount).to.equal(groupedSignalCount);
	});
});

describe(@"starting signals", ^{
	describe(@"+startLazilyWithScheduler:block:", ^{
		itBehavesLike(RACSignalStartSharedExamplesName, ^{
			NSArray *expectedValues = @[ @42, @43 ];
			RACScheduler *scheduler = [RACScheduler scheduler];
			RACSignal *signal = [RACSignal startLazilyWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
				for (id value in expectedValues) {
					[subscriber sendNext:value];
				}
				[subscriber sendCompleted];
			}];
			return @{
				RACSignalStartSignal: signal,
				RACSignalStartExpectedValues: expectedValues,
				RACSignalStartExpectedScheduler: scheduler,
			};
		});

		__block NSUInteger invokedCount = 0;
		__block void (^subscribe)(void);

		beforeEach(^{
			invokedCount = 0;

			RACSignal *signal = [RACSignal startLazilyWithScheduler:RACScheduler.immediateScheduler block:^(id<RACSubscriber> subscriber) {
				invokedCount++;
				[subscriber sendNext:@42];
				[subscriber sendCompleted];
			}];

			subscribe = [^{
				[signal subscribe:[RACSubscriber subscriberWithNext:nil error:nil completed:nil]];
			} copy];
		});

		it(@"should only invoke the block on subscription", ^{
			expect(invokedCount).to.equal(0);
			subscribe();
			expect(invokedCount).to.equal(1);
		});

		it(@"should only invoke the block once", ^{
			expect(invokedCount).to.equal(0);
			subscribe();
			expect(invokedCount).to.equal(1);
			subscribe();
			expect(invokedCount).to.equal(1);
			subscribe();
			expect(invokedCount).to.equal(1);
		});

		it(@"should invoke the block on the given scheduler", ^{
			RACScheduler *scheduler = [RACScheduler scheduler];
			__block RACScheduler *currentScheduler;
			[[[RACSignal
				startLazilyWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
					currentScheduler = RACScheduler.currentScheduler;
				}]
				publish]
				connect];

			expect(currentScheduler).will.equal(scheduler);
		});
	});

	describe(@"+startEagerlyWithScheduler:block:", ^{
		itBehavesLike(RACSignalStartSharedExamplesName, ^{
			NSArray *expectedValues = @[ @42, @43 ];
			RACScheduler *scheduler = [RACScheduler scheduler];
			RACSignal *signal = [RACSignal startEagerlyWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
				for (id value in expectedValues) {
					[subscriber sendNext:value];
				}
				[subscriber sendCompleted];
			}];
			return @{
				RACSignalStartSignal: signal,
				RACSignalStartExpectedValues: expectedValues,
				RACSignalStartExpectedScheduler: scheduler,
			};
		});

		it(@"should immediately invoke the block", ^{
			__block BOOL blockInvoked = NO;
			[RACSignal startEagerlyWithScheduler:[RACScheduler scheduler] block:^(id<RACSubscriber> subscriber) {
				blockInvoked = YES;
			}];

			expect(blockInvoked).will.beTruthy();
		});

		it(@"should only invoke the block once", ^{
			__block NSUInteger invokedCount = 0;
			RACSignal *signal = [RACSignal startEagerlyWithScheduler:RACScheduler.immediateScheduler block:^(id<RACSubscriber> subscriber) {
				invokedCount++;
			}];

			expect(invokedCount).to.equal(1);

			[[signal publish] connect];
			expect(invokedCount).to.equal(1);

			[[signal publish] connect];
			expect(invokedCount).to.equal(1);
		});

		it(@"should invoke the block on the given scheduler", ^{
			RACScheduler *scheduler = [RACScheduler scheduler];
			__block RACScheduler *currentScheduler;
			[RACSignal startEagerlyWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
				currentScheduler = RACScheduler.currentScheduler;
			}];

			expect(currentScheduler).will.equal(scheduler);
		});
	});
});

describe(@"-toArray", ^{
	__block RACSubject *subject;
	
	beforeEach(^{
		subject = [RACReplaySubject subject];
	});
	
	it(@"should return an array which contains NSNulls for nil values", ^{
		NSArray *expected = @[ NSNull.null, @1, NSNull.null ];
		
		[subject sendNext:nil];
		[subject sendNext:@1];
		[subject sendNext:nil];
		[subject sendCompleted];
		
		expect([subject toArray]).to.equal(expected);
	});

	it(@"should return nil upon error", ^{
		[subject sendError:nil];
		expect([subject toArray]).to.beNil();
	});

	it(@"should return nil upon error even if some nexts were sent", ^{
		[subject sendNext:@1];
		[subject sendNext:@2];
		[subject sendError:nil];
		
		expect([subject toArray]).to.beNil();
	});
});

describe(@"-ignore:", ^{
	it(@"should ignore nil", ^{
		RACSignal *signal = [[RACSignal
			createSignal:^ id (id<RACSubscriber> subscriber) {
				[subscriber sendNext:@1];
				[subscriber sendNext:nil];
				[subscriber sendNext:@3];
				[subscriber sendNext:@4];
				[subscriber sendNext:nil];
				[subscriber sendCompleted];
				return nil;
			}]
			ignore:nil];
		
		NSArray *expected = @[ @1, @3, @4 ];
		expect([signal toArray]).to.equal(expected);
	});
});

describe(@"-replayLazily", ^{
	__block NSUInteger subscriptionCount;
	__block BOOL disposed;

	__block RACSignal *signal;
	__block RACSubject *disposeSubject;
	__block RACSignal *replayedSignal;

	beforeEach(^{
		subscriptionCount = 0;
		disposed = NO;

		signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			subscriptionCount++;
			[subscriber sendNext:RACUnit.defaultUnit];

			RACDisposable *schedulingDisposable = [RACScheduler.mainThreadScheduler schedule:^{
				[subscriber sendNext:RACUnit.defaultUnit];
				[subscriber sendCompleted];
			}];

			return [RACDisposable disposableWithBlock:^{
				[schedulingDisposable dispose];
				disposed = YES;
			}];
		}];

		disposeSubject = [RACSubject subject];
		replayedSignal = [[signal takeUntil:disposeSubject] replayLazily];
	});

	it(@"should forward the input signal upon subscription", ^{
		expect(subscriptionCount).to.equal(0);

		expect([replayedSignal asynchronouslyWaitUntilCompleted:NULL]).to.beTruthy();
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should replay the input signal for future subscriptions", ^{
		NSArray *events = [[[replayedSignal materialize] collect] asynchronousFirstOrDefault:nil success:NULL error:NULL];
		expect(events).notTo.beNil();

		expect([[[replayedSignal materialize] collect] asynchronousFirstOrDefault:nil success:NULL error:NULL]).to.equal(events);
		expect(subscriptionCount).to.equal(1);
	});

	it(@"should replay even after disposal", ^{
		__block NSUInteger valueCount = 0;
		[replayedSignal subscribeNext:^(id x) {
			valueCount++;
		}];

		[disposeSubject sendCompleted];
		expect(valueCount).to.equal(1);
		expect([[replayedSignal toArray] count]).to.equal(valueCount);
	});
});

describe(@"-reduceApply", ^{
	it(@"should apply a block to the rest of a tuple", ^{
		RACSubject *subject = [RACReplaySubject subject];
		
		id sum = ^(NSNumber *a, NSNumber *b) {
			return @(a.intValue + b.intValue);
		};
		id madd = ^(NSNumber *a, NSNumber *b, NSNumber *c) {
			return @(a.intValue * b.intValue + c.intValue);
		};
		
		[subject sendNext:RACTuplePack(sum, @1, @2)];
		[subject sendNext:RACTuplePack(madd, @2, @3, @1)];
		[subject sendCompleted];
		
		NSArray *results = [[subject reduceApply] toArray];
		NSArray *expected = @[ @3, @7 ];
		
		expect(results).to.equal(expected);
	});
});

SpecEnd
