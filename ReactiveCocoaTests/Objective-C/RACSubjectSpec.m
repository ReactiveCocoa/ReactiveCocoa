//
//  RACSubjectSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSubscriberExamples.h"

#import <libkern/OSAtomic.h>
#import "EXTScope.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACUnit.h"

QuickSpecBegin(RACSubjectSpec)

qck_describe(@"RACSubject", ^{
	__block RACSubject *subject;
	__block NSMutableArray *values;

	__block BOOL success;
	__block NSError *error;

	qck_beforeEach(^{
		values = [NSMutableArray array];

		subject = [RACSubject subject];
		success = YES;
		error = nil;

		[subject subscribeNext:^(id value) {
			[values addObject:value];
		} error:^(NSError *e) {
			error = e;
			success = NO;
		} completed:^{
			success = YES;
		}];
	});

	qck_itBehavesLike(RACSubscriberExamples, ^{
		return @{
			RACSubscriberExampleSubscriber: subject,
			RACSubscriberExampleValuesReceivedBlock: [^{ return [values copy]; } copy],
			RACSubscriberExampleErrorReceivedBlock: [^{ return error; } copy],
			RACSubscriberExampleSuccessBlock: [^{ return success; } copy]
		};
	});
});

qck_describe(@"RACReplaySubject", ^{
	__block RACReplaySubject *subject = nil;

	qck_describe(@"with a capacity of 1", ^{
		qck_beforeEach(^{
			subject = [RACReplaySubject replaySubjectWithCapacity:1];
		});

		qck_it(@"should send the last value", ^{
			id firstValue = @"blah";
			id secondValue = @"more blah";

			[subject sendNext:firstValue];
			[subject sendNext:secondValue];

			__block id valueReceived = nil;
			[subject subscribeNext:^(id x) {
				valueReceived = x;
			}];

			expect(valueReceived).to(equal(secondValue));
		});

		qck_it(@"should send the last value to new subscribers after completion", ^{
			id firstValue = @"blah";
			id secondValue = @"more blah";

			__block id valueReceived = nil;
			__block NSUInteger nextsReceived = 0;

			[subject sendNext:firstValue];
			[subject sendNext:secondValue];

			expect(@(nextsReceived)).to(equal(@0));
			expect(valueReceived).to(beNil());

			[subject sendCompleted];

			[subject subscribeNext:^(id x) {
				valueReceived = x;
				nextsReceived++;
			}];

			expect(@(nextsReceived)).to(equal(@1));
			expect(valueReceived).to(equal(secondValue));
		});

		qck_it(@"should not send any values to new subscribers if none were sent originally", ^{
			[subject sendCompleted];

			__block BOOL nextInvoked = NO;
			[subject subscribeNext:^(id x) {
				nextInvoked = YES;
			}];

			expect(@(nextInvoked)).to(beFalsy());
		});

		qck_it(@"should resend errors", ^{
			NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
			[subject sendError:error];

			__block BOOL errorSent = NO;
			[subject subscribeError:^(NSError *sentError) {
				expect(sentError).to(equal(error));
				errorSent = YES;
			}];

			expect(@(errorSent)).to(beTruthy());
		});

		qck_it(@"should resend nil errors", ^{
			[subject sendError:nil];

			__block BOOL errorSent = NO;
			[subject subscribeError:^(NSError *sentError) {
				expect(sentError).to(beNil());
				errorSent = YES;
			}];

			expect(@(errorSent)).to(beTruthy());
		});
	});

	qck_describe(@"with an unlimited capacity", ^{
		qck_beforeEach(^{
			subject = [RACReplaySubject subject];
		});

		qck_itBehavesLike(RACSubscriberExamples, ^{
			return @{
				RACSubscriberExampleSubscriber: subject,
				RACSubscriberExampleValuesReceivedBlock: [^{
					NSMutableArray *values = [NSMutableArray array];

					// This subscription should synchronously dump all values already
					// received into 'values'.
					[subject subscribeNext:^(id value) {
						[values addObject:value];
					}];

					return values;
				} copy],
				RACSubscriberExampleErrorReceivedBlock: [^{
					__block NSError *error = nil;

					[subject subscribeError:^(NSError *x) {
						error = x;
					}];

					return error;
				} copy],
				RACSubscriberExampleSuccessBlock: [^{
					__block BOOL success = YES;

					[subject subscribeError:^(NSError *x) {
						success = NO;
					}];

					return success;
				} copy]
			};
		});

		qck_it(@"should send both values to new subscribers after completion", ^{
			id firstValue = @"blah";
			id secondValue = @"more blah";

			[subject sendNext:firstValue];
			[subject sendNext:secondValue];
			[subject sendCompleted];

			__block BOOL completed = NO;
			NSMutableArray *valuesReceived = [NSMutableArray array];
			[subject subscribeNext:^(id x) {
				[valuesReceived addObject:x];
			} completed:^{
				completed = YES;
			}];

			expect(@(valuesReceived.count)).to(equal(@2));
			NSArray *expected = [NSArray arrayWithObjects:firstValue, secondValue, nil];
			expect(valuesReceived).to(equal(expected));
			expect(@(completed)).to(beTruthy());
		});

		qck_it(@"should send values in the same order live as when replaying", ^{
			NSUInteger count = 49317;

			// Just leak it, ain't no thang.
			__unsafe_unretained volatile id *values = (__unsafe_unretained id *)calloc(count, sizeof(*values));
			__block volatile int32_t nextIndex = 0;

			[subject subscribeNext:^(NSNumber *value) {
				int32_t indexPlusOne = OSAtomicIncrement32(&nextIndex);
				values[indexPlusOne - 1] = value;
			}];

			dispatch_queue_t queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACSubjectSpec", DISPATCH_QUEUE_CONCURRENT);
			dispatch_suspend(queue);

			for (NSUInteger i = 0; i < count; i++) {
				dispatch_async(queue, ^{
					[subject sendNext:@(i)];
				});
			}

			dispatch_resume(queue);
			dispatch_barrier_sync(queue, ^{
				[subject sendCompleted];
			});

			OSMemoryBarrier();

			NSArray *liveValues = [NSArray arrayWithObjects:(id *)values count:(NSUInteger)nextIndex];
			expect(@(liveValues.count)).to(equal(@(count)));

			NSArray *replayedValues = subject.toArray;
			expect(@(replayedValues.count)).to(equal(@(count)));

			// It should return the same ordering for multiple invocations too.
			expect(replayedValues).to(equal(subject.toArray));

			[replayedValues enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
				expect(liveValues[index]).to(equal(value));
			}];
		});

		qck_it(@"should have a current scheduler when replaying", ^{
			[subject sendNext:RACUnit.defaultUnit];

			__block RACScheduler *currentScheduler;
			[subject subscribeNext:^(id x) {
				currentScheduler = RACScheduler.currentScheduler;
			}];

			expect(currentScheduler).notTo(beNil());

			currentScheduler = nil;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[subject subscribeNext:^(id x) {
					currentScheduler = RACScheduler.currentScheduler;
				}];
			});

			expect(currentScheduler).toEventuallyNot(beNil());
		});

		qck_it(@"should stop replaying when the subscription is disposed", ^{
			NSMutableArray *values = [NSMutableArray array];

			[subject sendNext:@0];
			[subject sendNext:@1];

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				__block RACDisposable *disposable = [subject subscribeNext:^(id x) {
					expect(disposable).notTo(beNil());

					[values addObject:x];
					[disposable dispose];
				}];
			});

			expect(values).toEventually(equal(@[ @0 ]));
		});

		qck_it(@"should finish replaying before completing", ^{
			[subject sendNext:@1];

			__block id received;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[subject subscribeNext:^(id x) {
					received = x;
				}];

				[subject sendCompleted];
			});

			expect(received).toEventually(equal(@1));
		});

		qck_it(@"should finish replaying before erroring", ^{
			[subject sendNext:@1];

			__block id received;
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[subject subscribeNext:^(id x) {
					received = x;
				}];

				[subject sendError:[NSError errorWithDomain:@"blah" code:-99 userInfo:nil]];
			});

			expect(received).toEventually(equal(@1));
		});

		qck_it(@"should finish replaying before sending new values", ^{
			[subject sendNext:@1];

			NSMutableArray *received = [NSMutableArray array];
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				[subject subscribeNext:^(id x) {
					[received addObject:x];
				}];

				[subject sendNext:@2];
			});

			NSArray *expected = @[ @1, @2 ];
			expect(received).toEventually(equal(expected));
		});
	});
});

QuickSpecEnd
