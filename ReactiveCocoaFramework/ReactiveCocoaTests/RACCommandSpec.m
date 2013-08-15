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
		__block id valueReceived = nil;
		[command.executionSignals subscribeNext:^(RACSignal *signal) {
			expect(signal).to.beKindOf(RACSignal.class);
			valueReceived = [signal first];
		}];
		
		id sentValue = NSNull.null;
		RACSignal *signal = [command execute:sentValue];
		expect(valueReceived).to.equal(sentValue);
		expect([signal first]).to.equal(valueReceived);
	});

	it(@"should not send anything on 'errors' by default", ^{
		__block BOOL receivedError = NO;
		[command.errors subscribeNext:^(id _) {
			receivedError = YES;
		}];
		
		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect(receivedError).to.beFalsy();
	});

	it(@"should be executing from within the -execute: method", ^{
		[command.executionSignals subscribeNext:^(id _) {
			expect(command.executing).to.beTruthy();
		}];

		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect(command.executing).to.beFalsy();
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

describe(@"with a signal block", ^{
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

	it(@"should forward errors onto 'errors'", ^{
		RACCommand *command = [[RACCommand alloc] initWithSignalBlock:^(RACSignal *signal) {
			return signal;
		}];
		
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

	it(@"should not forward other events onto 'errors'", ^{
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
});

describe(@"enabled", ^{
	__block RACSubject *enabledSubject;
	__block RACCommand *command;

	beforeEach(^{
		enabledSubject = [RACSubject subject];
		command = [[RACCommand alloc] initWithEnabled:enabledSubject signalBlock:^(id _) {
			return [RACSignal return:RACUnit.defaultUnit];
		}];
	});

	it(@"should be YES by default", ^{
		expect([command.enabled first]).to.equal(@YES);
	});

	it(@"should be whatever the enabledSignal has sent most recently", ^{
		[enabledSubject sendNext:@NO];
		expect([command.enabled first]).to.equal(@NO);

		[enabledSubject sendNext:@YES];
		expect([command.enabled first]).to.equal(@YES);

		[enabledSubject sendNext:@NO];
		expect([command.enabled first]).to.equal(@NO);
	});

	it(@"should be NO while executing is YES and allowsConcurrentExecution is NO", ^{
		[[command.executionSignals flatten] subscribeNext:^(id _) {
			expect([command.executing first]).to.equal(@YES);
			expect([command.enabled first]).to.equal(@NO);
		}];

		expect([command.enabled first]).to.equal(@YES);
		expect([[command execute:nil] waitUntilCompleted:NULL]).to.beTruthy();
		expect([command.enabled first]).to.equal(@YES);
	});

	it(@"should be YES while executing is YES and allowsConcurrentExecution is YES", ^{
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
