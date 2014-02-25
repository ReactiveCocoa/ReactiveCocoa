//
//  RACSignalSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTestObject.h"

#import "NSObject+RACDeallocating.h"
#import "RACCompoundDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTestScheduler.h"
#import "RACUnit.h"

SpecBegin(RACSignal)

describe(@"subscribing", ^{
	__block BOOL disposed;
	__block RACSignal *signal = nil;

	id nextValueSent = @"1";
	
	beforeEach(^{
		disposed = NO;
		signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendCompleted];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
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

		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@0];

			[scheduler afterDelay:0 schedule:^{
				[subscriber sendNext:@1];
			}];
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
	
	it(@"should automatically dispose of other subscriptions from +create:", ^{
		__block BOOL innerDisposed = NO;
		__block id<RACSubscriber> innerSubscriber = nil;

		RACSignal *innerSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			// Keep the subscriber alive so it doesn't trigger disposal on dealloc
			innerSubscriber = subscriber;
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}]];
		}];

		RACSignal *outerSignal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[innerSignal subscribe:subscriber];
		}];

		RACDisposable *disposable = [outerSignal subscribe:nil];
		expect(disposable).notTo.beNil();
		expect(innerDisposed).to.beFalsy();

		[disposable dispose];
		expect(innerDisposed).to.beTruthy();
	});

	it(@"should save a disposable in -subscribeSavingDisposable:next:error:completed:", ^{
		__block RACDisposable *disposable = nil;
		__block id nextValue = nil;
		__block BOOL completed = NO;

		[signal subscribeSavingDisposable:^(RACDisposable *d) {
			disposable = d;

			expect(disposable).notTo.beNil();
			expect(disposable.disposed).to.beFalsy();
			expect(disposed).to.beFalsy();
		} next:^(id x) {
			nextValue = x;

			expect(disposable).notTo.beNil();
			expect(disposable.disposed).to.beFalsy();
			expect(disposed).to.beFalsy();

			[disposable dispose];
		} error:nil completed:^{
			completed = YES;
		}];

		expect(disposed).to.beTruthy();
		expect(disposable.disposed).to.beTruthy();
		expect(nextValue).to.equal(nextValueSent);
		expect(completed).to.beFalsy();
	});
});

describe(@"disposal", ^{
	it(@"should dispose of the didSubscribe disposable", ^{
		__block BOOL innerDisposed = NO;
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}]];
		}];

		expect(innerDisposed).to.beFalsy();

		RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
		expect(disposable).notTo.beNil();

		[disposable dispose];
		expect(innerDisposed).to.beTruthy();
	});

	it(@"should dispose of the didSubscribe disposable asynchronously", ^{
		__block BOOL innerDisposed = NO;
		RACSignal *signal = [RACSignal create:^(id<RACSubscriber> subscriber) {
			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}]];
		}];

		[[RACScheduler scheduler] schedule:^{
			RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
			[disposable dispose];
		}];

		expect(innerDisposed).will.beTruthy();
	});
});

describe(@"memory management", ^{
	it(@"should dealloc signals if the signal does nothing", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal create:^(id<RACSubscriber> subscriber) {
			}];

			[signal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
		}

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc signals if the signal immediately completes", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			__block BOOL done = NO;

			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal create:^(id<RACSubscriber> subscriber) {
				[subscriber sendCompleted];
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

	it(@"should dealloc if the signal was created on a background queue", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[[RACScheduler scheduler] schedule:^{
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal create:^(id<RACSubscriber> subscriber) {
					[subscriber sendCompleted];
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
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal create:^(id<RACSubscriber> subscriber) {
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

	it(@"should work if intermediate signals are unreferenced", ^{
		RACSubject *subject = [RACSubject subject];
		expect(subject).notTo.beNil();

		__block BOOL gotNext = NO;
		__block BOOL completed = NO;

		RACDisposable *disposable;

		@autoreleasepool {
			RACSignal *intermediateSignal = [subject doNext:^(id _) {
				gotNext = YES;
			}];

			expect(intermediateSignal).notTo.beNil();

			disposable = [intermediateSignal subscribeCompleted:^{
				completed = YES;
			}];
		}

		[subject sendNext:@5];
		expect(gotNext).to.beTruthy();

		[subject sendCompleted];
		expect(completed).to.beTruthy();
		
		[disposable dispose];
	});
});

SpecEnd
