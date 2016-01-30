//
//  RACCommandSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 8/31/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

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

QuickSpecBegin(RACCommandSpec)

RACSignal * (^emptySignalBlock)(id) = ^(id _) {
	return [RACSignal empty];
};

qck_describe(@"with a simple signal block", ^{
	__block RACCommand *command;

	qck_beforeEach(^{
		command = [[RACCommand alloc] initWithSignalBlock:^(id value) {
			return [RACSignal return:value];
		}];

		expect(command).notTo(beNil());
		expect(@(command.allowsConcurrentExecution)).to(beFalsy());
	});

	qck_it(@"should be enabled by default", ^{
		expect([command.enabled first]).to(equal(@YES));
	});

	qck_it(@"should not be executing by default", ^{
		expect([command.executing first]).to(equal(@NO));
	});

	qck_it(@"should create an execution signal", ^{
		__block NSUInteger signalsReceived = 0;
		__block BOOL completed = NO;

		id value = NSNull.null;
		[command.executionSignals subscribeNext:^(RACSignal *signal) {
			signalsReceived++;

			[signal subscribeNext:^(id x) {
				expect(x).to(equal(value));
			} completed:^{
				completed = YES;
			}];
		}];

		expect(@(signalsReceived)).to(equal(@0));
		
		[command execute:value];
		expect(@(signalsReceived)).toEventually(equal(@1));
		expect(@(completed)).to(beTruthy());
	});

	qck_it(@"should return the execution signal from -execute:", ^{
		__block BOOL completed = NO;

		id value = NSNull.null;
		[[command
			execute:value]
			subscribeNext:^(id x) {
				expect(x).to(equal(value));
			} completed:^{
				completed = YES;
			}];

		expect(@(completed)).toEventually(beTruthy());
	});

	qck_it(@"should always send executionSignals on the main thread", ^{
		__block RACScheduler *receivedScheduler = nil;
		[command.executionSignals subscribeNext:^(id _) {
			receivedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			expect(@([[command execute:nil] waitUntilCompleted:NULL])).to(beTruthy());
		}];

		expect(receivedScheduler).to(beNil());
		expect(receivedScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
	});

	qck_it(@"should not send anything on 'errors' by default", ^{
		__block BOOL receivedError = NO;
		[command.errors subscribeNext:^(id _) {
			receivedError = YES;
		}];
		
		expect(@([[command execute:nil] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
		expect(@(receivedError)).to(beFalsy());
	});

	qck_it(@"should be executing while an execution signal is running", ^{
		[command.executionSignals subscribeNext:^(RACSignal *signal) {
			[signal subscribeNext:^(id x) {
				expect([command.executing first]).to(equal(@YES));
			}];
		}];

		expect(@([[command execute:nil] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
		expect([command.executing first]).to(equal(@NO));
	});

	qck_it(@"should always update executing on the main thread", ^{
		__block RACScheduler *updatedScheduler = nil;
		[[command.executing skip:1] subscribeNext:^(NSNumber *executing) {
			if (!executing.boolValue) return;

			updatedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			expect(@([[command execute:nil] waitUntilCompleted:NULL])).to(beTruthy());
		}];

		expect([command.executing first]).to(equal(@NO));
		expect(updatedScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
	});

	qck_it(@"should dealloc without subscribers", ^{
		__block BOOL disposed = NO;

		@autoreleasepool {
			RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithSignalBlock:emptySignalBlock];
			[command.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}

		expect(@(disposed)).toEventually(beTruthy());
	});

	qck_it(@"should complete signals on the main thread when deallocated", ^{
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

		expect(executionSignalsScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
		expect(executingScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
		expect(enabledScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
		expect(errorsScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
	});
});

qck_it(@"should invoke the signalBlock once per execution", ^{
	NSMutableArray *valuesReceived = [NSMutableArray array];
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(id x) {
		[valuesReceived addObject:x];
		return [RACSignal empty];
	}];

	expect(@([[command execute:@"foo"] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
	expect(valuesReceived).to(equal((@[ @"foo" ])));

	expect(@([[command execute:@"bar"] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
	expect(valuesReceived).to(equal((@[ @"foo", @"bar" ])));
});

qck_it(@"should send on executionSignals in order of execution", ^{
	RACCommand<RACSequence *> *command = [[RACCommand alloc] initWithSignalBlock:^(RACSequence *seq) {
		return [seq signalWithScheduler:RACScheduler.immediateScheduler];
	}];

	NSMutableArray *valuesReceived = [NSMutableArray array];
	[[command.executionSignals
		concat]
		subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

	RACSequence *first = @[ @"foo", @"bar" ].rac_sequence;
	expect(@([[command execute:first] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());

	RACSequence *second = @[ @"buzz", @"baz" ].rac_sequence;
	expect(@([[command execute:second] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());

	NSArray *expectedValues = @[ @"foo", @"bar", @"buzz", @"baz" ];
	expect(valuesReceived).to(equal(expectedValues));
});

qck_it(@"should wait for all signals to complete or error before executing sends NO", ^{
	RACCommand<RACSignal *> *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];

	command.allowsConcurrentExecution = YES;
	
	RACSubject *firstSubject = [RACSubject subject];
	expect([command execute:firstSubject]).notTo(beNil());

	RACSubject *secondSubject = [RACSubject subject];
	expect([command execute:secondSubject]).notTo(beNil());

	expect([command.executing first]).toEventually(equal(@YES));

	[firstSubject sendError:nil];
	expect([command.executing first]).to(equal(@YES));

	[secondSubject sendNext:nil];
	expect([command.executing first]).to(equal(@YES));

	[secondSubject sendCompleted];
	expect([command.executing first]).toEventually(equal(@NO));
});

qck_it(@"should have allowsConcurrentExecution be observable", ^{
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];
	
	RACSubject *completion = [RACSubject subject];
	RACSignal *allowsConcurrentExecution = [[RACObserve(command, allowsConcurrentExecution)
		takeUntil:completion]
		replayLast];
	
	command.allowsConcurrentExecution = YES;
	
	expect([allowsConcurrentExecution first]).to(beTrue());
	[completion sendCompleted];
});

qck_it(@"should not deliver errors from executionSignals", ^{
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

	expect([command execute:nil]).notTo(beNil());
	expect([command.executing first]).toEventually(equal(@YES));

	[subject sendNext:RACUnit.defaultUnit];

	NSArray *expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit] ];
	expect(receivedEvents).toEventually(equal(expectedEvents));
	expect([command.executing first]).to(equal(@YES));

	[subject sendNext:@"foo"];

	expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"] ];
	expect(receivedEvents).toEventually(equal(expectedEvents));
	expect([command.executing first]).to(equal(@YES));

	NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];
	[subject sendError:error];

	expect([command.executing first]).toEventually(equal(@NO));
	expect(receivedEvents).to(equal(expectedEvents));
});

qck_it(@"should deliver errors from -execute:", ^{
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

	expect([command.executing first]).toEventually(equal(@YES));

	[subject sendNext:RACUnit.defaultUnit];

	NSArray *expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit] ];
	expect(receivedEvents).toEventually(equal(expectedEvents));
	expect([command.executing first]).to(equal(@YES));

	[subject sendNext:@"foo"];

	expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"] ];
	expect(receivedEvents).toEventually(equal(expectedEvents));
	expect([command.executing first]).to(equal(@YES));

	NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];
	[subject sendError:error];

	expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"], [RACEvent eventWithError:error] ];
	expect(receivedEvents).toEventually(equal(expectedEvents));
	expect([command.executing first]).toEventually(equal(@NO));
});

qck_it(@"should deliver errors onto 'errors'", ^{
	RACCommand<RACSignal *> *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];

	command.allowsConcurrentExecution = YES;
	
	RACSubject *firstSubject = [RACSubject subject];
	expect([command execute:firstSubject]).notTo(beNil());

	RACSubject *secondSubject = [RACSubject subject];
	expect([command execute:secondSubject]).notTo(beNil());

	NSError *firstError = [NSError errorWithDomain:@"" code:1 userInfo:nil];
	NSError *secondError = [NSError errorWithDomain:@"" code:2 userInfo:nil];
	
	// We should receive errors from our previously-started executions.
	NSMutableArray *receivedErrors = [NSMutableArray array];
	[command.errors subscribeNext:^(NSError *error) {
		[receivedErrors addObject:error];
	}];

	expect([command.executing first]).toEventually(equal(@YES));

	[firstSubject sendError:firstError];
	expect([command.executing first]).toEventually(equal(@YES));

	NSArray *expected = @[ firstError ];
	expect(receivedErrors).toEventually(equal(expected));

	[secondSubject sendError:secondError];
	expect([command.executing first]).toEventually(equal(@NO));

	expected = @[ firstError, secondError ];
	expect(receivedErrors).toEventually(equal(expected));
});

qck_it(@"should not deliver non-error events onto 'errors'", ^{
	RACSubject *subject = [RACSubject subject];
	RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
		return subject;
	}];

	__block BOOL receivedEvent = NO;
	[command.errors subscribeNext:^(id _) {
		receivedEvent = YES;
	}];

	expect([command execute:nil]).notTo(beNil());
	expect([command.executing first]).toEventually(equal(@YES));

	[subject sendNext:RACUnit.defaultUnit];
	[subject sendCompleted];

	expect([command.executing first]).toEventually(equal(@NO));
	expect(@(receivedEvent)).to(beFalsy());
});

qck_it(@"should send errors on the main thread", ^{
	RACCommand<RACSignal *> *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
		return signal;
	}];

	NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];

	__block RACScheduler *receivedScheduler = nil;
	[command.errors subscribeNext:^(NSError *e) {
		expect(e).to(equal(error));
		receivedScheduler = RACScheduler.currentScheduler;
	}];

	RACSignal *errorSignal = [RACSignal error:error];

	[[RACScheduler scheduler] schedule:^{
		[command execute:errorSignal];
	}];

	expect(receivedScheduler).to(beNil());
	expect(receivedScheduler).toEventually(equal(RACScheduler.mainThreadScheduler));
});

qck_describe(@"enabled signal", ^{
	__block RACSubject *enabledSubject;
	__block RACCommand *command;

	qck_beforeEach(^{
		enabledSubject = [RACSubject subject];
		command = [[RACCommand alloc] initWithEnabled:enabledSubject signalBlock:^(id _) {
			return [RACSignal return:RACUnit.defaultUnit];
		}];
	});

	qck_it(@"should send YES by default", ^{
		expect([command.enabled first]).to(equal(@YES));
	});

	qck_it(@"should send whatever the enabledSignal has sent most recently", ^{
		[enabledSubject sendNext:@NO];
		expect([command.enabled first]).toEventually(equal(@NO));

		[enabledSubject sendNext:@YES];
		expect([command.enabled first]).toEventually(equal(@YES));

		[enabledSubject sendNext:@NO];
		expect([command.enabled first]).toEventually(equal(@NO));
	});
	
	qck_it(@"should sample enabledSignal synchronously at initialization time", ^{
		RACCommand *command = [[RACCommand alloc] initWithEnabled:[RACSignal return:@NO] signalBlock:^(id _) {
			return [RACSignal empty];
		}];
		expect([command.enabled first]).to(equal(@NO));
	});

	qck_it(@"should send NO while executing is YES and allowsConcurrentExecution is NO", ^{
		[[command.executionSignals flatten] subscribeNext:^(id _) {
			expect([command.executing first]).to(equal(@YES));
			expect([command.enabled first]).to(equal(@NO));
		}];

		expect([command.enabled first]).to(equal(@YES));
		expect(@([[command execute:nil] asynchronouslyWaitUntilCompleted:NULL])).to(beTruthy());
		expect([command.enabled first]).to(equal(@YES));
	});

	qck_it(@"should send YES while executing is YES and allowsConcurrentExecution is YES", ^{
		command.allowsConcurrentExecution = YES;

		__block BOOL outerExecuted = NO;
		__block BOOL innerExecuted = NO;

		// Prevent infinite recursion by only responding to the first value.
		[[[command.executionSignals
			take:1]
			flatten]
			subscribeNext:^(id _) {
				outerExecuted = YES;

				expect([command.executing first]).to(equal(@YES));
				expect([command.enabled first]).to(equal(@YES));

				[[command execute:nil] subscribeCompleted:^{
					innerExecuted = YES;
				}];
			}];

		expect([command.enabled first]).to(equal(@YES));

		expect([command execute:nil]).notTo(beNil());
		expect(@(outerExecuted)).toEventually(beTruthy());
		expect(@(innerExecuted)).toEventually(beTruthy());

		expect([command.enabled first]).to(equal(@YES));
	});

	qck_it(@"should send an error from -execute: when NO", ^{
		[enabledSubject sendNext:@NO];

		RACSignal *signal = [command execute:nil];
		expect(signal).notTo(beNil());
		
		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:nil success:&success error:&error]).to(beNil());
		expect(@(success)).to(beFalsy());

		expect(error).notTo(beNil());
		expect(error.domain).to(equal(RACCommandErrorDomain));
		expect(@(error.code)).to(equal(@(RACCommandErrorNotEnabled)));
		expect(error.userInfo[RACUnderlyingCommandErrorKey]).to(beIdenticalTo(command));
	});

	qck_it(@"should always update on the main thread", ^{
		__block RACScheduler *updatedScheduler = nil;
		[[command.enabled skip:1] subscribeNext:^(id _) {
			updatedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			[enabledSubject sendNext:@NO];
		}];

		expect([command.enabled first]).to(equal(@YES));
		expect([command.enabled first]).toEventually(equal(@NO));
		expect(updatedScheduler).to(equal(RACScheduler.mainThreadScheduler));
	});

	qck_it(@"should complete when the command is deallocated even if the input signal hasn't", ^{
		__block BOOL deallocated = NO;
		__block BOOL completed = NO;

		@autoreleasepool {
			RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithEnabled:enabledSubject signalBlock:emptySignalBlock];
			[command.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			[command.enabled subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(@(deallocated)).toEventually(beTruthy());
		expect(@(completed)).toEventually(beTruthy());
	});
});

QuickSpecEnd
