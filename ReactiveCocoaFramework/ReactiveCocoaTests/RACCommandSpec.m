//
//  RACCommandSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 8/31/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCommand.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACEvent.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACUnit.h"

SpecBegin(RACCommand)

RACSignal * (^emptySignalBlock)(id) = ^(id _) {
	return [RACSignal empty];
};

describe(@"with a simple signal block", ^{
	__block RACCommand *command;

	beforeEach(^{
		command = [[RACCommand alloc] initWithSignalBlock:^(id value) {
			return [RACSignal return:value];
		}];

		expect(command).notTo.beNil();
		expect(command.allowsConcurrentExecution).to.beFalsy();
	});

	it(@"should be enabled by default", ^{
		expect([command.enabled first]).to.equal(@YES);
	});

	it(@"should not be executing by default", ^{
		expect([command.executing first]).to.equal(@NO);
	});

	it(@"should create an execution signal", ^{
		__block NSUInteger signalsReceived = 0;
		__block BOOL completed = NO;

		id value = NSNull.null;
		[command.executionSignals subscribeNext:^(RACSignal *signal) {
			signalsReceived++;

			[signal subscribeNext:^(id x) {
				expect(x).to.equal(value);
			} completed:^{
				completed = YES;
			}];
		}];

		expect(signalsReceived).to.equal(0);
		
		[command execute:value];
		expect(signalsReceived).to.equal(1);
		expect(completed).to.beTruthy();
	});

	it(@"should return the execution signal from -execute:", ^{
		__block BOOL completed = NO;

		id value = NSNull.null;
		[[command
			execute:value]
			subscribeNext:^(id x) {
				expect(x).to.equal(value);
			} completed:^{
				completed = YES;
			}];

		expect(completed).to.beTruthy();
	});

	it(@"should always send executionSignals on the main thread", ^{
		__block RACScheduler *receivedScheduler = nil;
		[command.executionSignals subscribeNext:^(id _) {
			receivedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		}];

		expect(receivedScheduler).to.beNil();
		expect(receivedScheduler).will.equal(RACScheduler.mainThreadScheduler);
	});

	it(@"should not send anything on 'errors' by default", ^{
		__block BOOL receivedError = NO;
		[command.errors subscribeNext:^(id _) {
			receivedError = YES;
		}];
		
		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect(receivedError).to.beFalsy();
	});

	it(@"should be executing while an execution signal is running", ^{
		[command.executionSignals subscribeNext:^(RACSignal *signal) {
			[signal subscribeNext:^(id x) {
				expect([command.executing first]).to.equal(@YES);
			}];
		}];

		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect([command.executing first]).to.equal(@NO);
	});

	it(@"should always update executing on the main thread", ^{
		__block RACScheduler *updatedScheduler = nil;
		[[command.executing skip:1] subscribeNext:^(NSNumber *executing) {
			if (!executing.boolValue) return;

			updatedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		}];

		expect([command.executing first]).to.equal(@NO);
		expect(updatedScheduler).will.equal(RACScheduler.mainThreadScheduler);
	});

	it(@"should dealloc without subscribers", ^{
		__block BOOL disposed = NO;

		@autoreleasepool {
			RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithSignalBlock:emptySignalBlock];
			[command.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}

		expect(disposed).will.beTruthy();
	});

	it(@"should complete signals on the main thread when deallocated", ^{
		__block RACScheduler *executionSignalsScheduler = nil;
		__block RACScheduler *executingScheduler = nil;
		__block RACScheduler *enabledScheduler = nil;
		__block RACScheduler *errorsScheduler = nil;

		[[RACScheduler scheduler] schedule:^{
			@autoreleasepool {
				RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithSignalBlock:emptySignalBlock];

				[command.executionSignals subscribeCompleted:^{
					executionSignalsScheduler = RACScheduler.currentScheduler;
				}];

				[command.executing subscribeCompleted:^{
					executingScheduler = RACScheduler.currentScheduler;
				}];

				[command.enabled subscribeCompleted:^{
					enabledScheduler = RACScheduler.currentScheduler;
				}];

				[command.errors subscribeCompleted:^{
					errorsScheduler = RACScheduler.currentScheduler;
				}];
			}
		}];

		expect(executionSignalsScheduler).will.equal(RACScheduler.mainThreadScheduler);
		expect(executingScheduler).will.equal(RACScheduler.mainThreadScheduler);
		expect(enabledScheduler).will.equal(RACScheduler.mainThreadScheduler);
		expect(errorsScheduler).will.equal(RACScheduler.mainThreadScheduler);
	});
});

it(@"should invoke the signalBlock once per execution", ^{
	NSMutableArray *valuesReceived = [NSMutableArray array];
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(id x) {
		[valuesReceived addObject:x];
		return [RACSignal empty];
	}];

	expect([[command execute:@"foo"] waitUntilCompleted:NULL]).to.beTruthy();
	expect(valuesReceived).to.equal((@[ @"foo" ]));

	expect([[command execute:@"bar"] waitUntilCompleted:NULL]).to.beTruthy();
	expect(valuesReceived).to.equal((@[ @"foo", @"bar" ]));
});

it(@"should send on executionSignals in order of execution", ^{
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(RACSequence *seq) {
		return [seq signalWithScheduler:RACScheduler.immediateScheduler];
	}];

	NSMutableArray *valuesReceived = [NSMutableArray array];
	[[command.executionSignals
		concat]
		subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

	RACSequence *first = @[ @"foo", @"bar" ].rac_sequence;
	expect([[command execute:first] waitUntilCompleted:NULL]).to.beTruthy();

	RACSequence *second = @[ @"buzz", @"baz" ].rac_sequence;
	expect([[command execute:second] waitUntilCompleted:NULL]).will.beTruthy();

	NSArray *expectedValues = @[ @"foo", @"bar", @"buzz", @"baz" ];
	expect(valuesReceived).to.equal(expectedValues);
});

it(@"should wait for all signals to complete or error before executing sends NO", ^{
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];

	command.allowsConcurrentExecution = YES;
	
	RACSubject *firstSubject = [RACSubject subject];
	expect([command execute:firstSubject]).notTo.beNil();

	RACSubject *secondSubject = [RACSubject subject];
	expect([command execute:secondSubject]).notTo.beNil();

	expect([command.executing first]).to.equal(@YES);

	[firstSubject sendError:nil];
	expect([command.executing first]).to.equal(@YES);

	[secondSubject sendNext:nil];
	expect([command.executing first]).to.equal(@YES);

	[secondSubject sendCompleted];
	expect([command.executing first]).to.equal(@NO);
});

it(@"should not deliver errors from executionSignals", ^{
	RACSubject *subject = [RACSubject subject];
	NSMutableArray *receivedEvents = [NSMutableArray array];

	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
		return subject;
	}];

	[[[command.executionSignals
		flatten]
		materialize]
		subscribeNext:^(RACEvent *event) {
			[receivedEvents addObject:event];
		}];

	expect([command execute:nil]).notTo.beNil();
	expect([command.executing first]).to.equal(@YES);

	[subject sendNext:RACUnit.defaultUnit];

	NSArray *expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit] ];
	expect(receivedEvents).to.equal(expectedEvents);
	expect([command.executing first]).to.equal(@YES);

	[subject sendNext:@"foo"];

	expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"] ];
	expect(receivedEvents).to.equal(expectedEvents);
	expect([command.executing first]).to.equal(@YES);

	NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];
	[subject sendError:error];

	expect([command.executing first]).to.equal(@NO);
	expect(receivedEvents).to.equal(expectedEvents);
});

it(@"should deliver errors from -execute:", ^{
	RACSubject *subject = [RACSubject subject];
	NSMutableArray *receivedEvents = [NSMutableArray array];

	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
		return subject;
	}];

	[[[command
		execute:nil]
		materialize]
		subscribeNext:^(RACEvent *event) {
			[receivedEvents addObject:event];
		}];

	expect([command.executing first]).to.equal(@YES);

	[subject sendNext:RACUnit.defaultUnit];

	NSArray *expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit] ];
	expect(receivedEvents).to.equal(expectedEvents);
	expect([command.executing first]).to.equal(@YES);

	[subject sendNext:@"foo"];

	expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"] ];
	expect(receivedEvents).to.equal(expectedEvents);
	expect([command.executing first]).to.equal(@YES);

	NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];
	[subject sendError:error];

	expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"], [RACEvent eventWithError:error] ];
	expect(receivedEvents).to.equal(expectedEvents);
	expect([command.executing first]).to.equal(@NO);
});

it(@"should deliver errors onto 'errors'", ^{
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];

	command.allowsConcurrentExecution = YES;
	
	RACSubject *firstSubject = [RACSubject subject];
	expect([command execute:firstSubject]).notTo.beNil();

	RACSubject *secondSubject = [RACSubject subject];
	expect([command execute:secondSubject]).notTo.beNil();

	NSError *firstError = [NSError errorWithDomain:@"" code:1 userInfo:nil];
	NSError *secondError = [NSError errorWithDomain:@"" code:2 userInfo:nil];
	
	NSMutableArray *receivedErrors = [NSMutableArray array];
	[command.errors subscribeNext:^(NSError *error) {
		[receivedErrors addObject:error];
	}];

	expect([command.executing first]).to.equal(@YES);

	[firstSubject sendError:firstError];
	expect([command.executing first]).to.equal(@YES);

	NSArray *expected = @[ firstError ];
	expect(receivedErrors).will.equal(expected);

	[secondSubject sendError:secondError];
	expect([command.executing first]).will.equal(@NO);

	expected = @[ firstError, secondError ];
	expect(receivedErrors).will.equal(expected);
});

it(@"should not deliver non-error events onto 'errors'", ^{
	RACSubject *subject = [RACSubject subject];
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
		return subject;
	}];

	__block BOOL receivedEvent = NO;
	[command.errors subscribeNext:^(id _) {
		receivedEvent = YES;
	}];

	expect([command execute:nil]).notTo.beNil();
	expect([command.executing first]).to.equal(@YES);

	[subject sendNext:RACUnit.defaultUnit];
	[subject sendCompleted];

	expect([command.executing first]).will.equal(@NO);
	expect(receivedEvent).to.beFalsy();
});

it(@"should send errors on the main thread", ^{
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];

	NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];

	__block RACScheduler *receivedScheduler = nil;
	[command.errors subscribeNext:^(NSError *e) {
		expect(e).to.equal(error);
		receivedScheduler = RACScheduler.currentScheduler;
	}];

	RACSignal *errorSignal = [RACSignal error:error];

	[[RACScheduler scheduler] schedule:^{
		expect([[command execute:errorSignal] waitUntilCompleted:NULL]).to.beTruthy();
	}];

	expect(receivedScheduler).to.beNil();
	expect(receivedScheduler).will.equal(RACScheduler.mainThreadScheduler);
});

describe(@"enabled property", ^{
	__block RACSubject *enabledSubject;
	__block RACCommand *command;

	beforeEach(^{
		enabledSubject = [RACSubject subject];
		command = [[RACCommand alloc] initWithEnabled:enabledSubject signalBlock:^(id _) {
			return [RACSignal return:RACUnit.defaultUnit];
		}];
	});

	it(@"should send YES by default", ^{
		expect([command.enabled first]).to.equal(@YES);
	});

	it(@"should send whatever the enabledSignal has sent most recently", ^{
		[enabledSubject sendNext:@NO];
		expect([command.enabled first]).to.equal(@NO);

		[enabledSubject sendNext:@YES];
		expect([command.enabled first]).to.equal(@YES);

		[enabledSubject sendNext:@NO];
		expect([command.enabled first]).to.equal(@NO);
	});

	it(@"should send NO while executing is YES and allowsConcurrentExecution is NO", ^{
		[[command.executionSignals flatten] subscribeNext:^(id _) {
			expect([command.executing first]).to.equal(@YES);
			expect([command.enabled first]).to.equal(@NO);
		}];

		expect([command.enabled first]).to.equal(@YES);
		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect([command.enabled first]).to.equal(@YES);
	});

	it(@"should send YES while executing is YES and allowsConcurrentExecution is YES", ^{
		command.allowsConcurrentExecution = YES;

		// Prevent infinite recursion by only responding to the first value.
		[[[command.executionSignals
			take:1]
			flatten]
			subscribeNext:^(id _) {
				expect([command.executing first]).to.equal(@YES);
				expect([command.enabled first]).to.equal(@YES);
				expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
			}];

		expect([command.enabled first]).to.equal(@YES);
		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect([command.enabled first]).to.equal(@YES);
	});

	it(@"should send NO while executing is YES and allowsConcurrentExecution is YES if enabledSignal sent NO", ^{
		command.allowsConcurrentExecution = YES;

		[[command.executionSignals flatten] subscribeNext:^(id _) {
			expect([command.executing first]).to.equal(@YES);
			expect([command.enabled first]).to.equal(@YES);

			[enabledSubject sendNext:@NO];
			expect([command.enabled first]).to.equal(@NO);
		}];

		expect([command.enabled first]).to.equal(@YES);
		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
	});

	it(@"should send an error from -execute: when NO", ^{
		[enabledSubject sendNext:@NO];

		RACSignal *signal = [command execute:nil];
		expect(signal).notTo.beNil();
		
		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:nil success:&success error:&error]).to.beNil();
		expect(success).to.beFalsy();

		expect(error).notTo.beNil();
		expect(error.domain).to.equal(RACCommandErrorDomain);
		expect(error.code).to.equal(RACCommandErrorNotEnabled);
	});

	it(@"should always update on the main thread", ^{
		__block RACScheduler *updatedScheduler = nil;
		[[command.enabled skip:1] subscribeNext:^(id _) {
			updatedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			[enabledSubject sendNext:@NO];
		}];

		expect([command.enabled first]).to.equal(@YES);
		expect([command.enabled first]).will.equal(@NO);
		expect(updatedScheduler).to.equal(RACScheduler.mainThreadScheduler);
	});
});

SpecEnd
