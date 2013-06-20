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

__block RACCommand *command;

beforeEach(^{
	command = [RACCommand command];
	expect(command).notTo.beNil();

	expect(command.canExecute).to.beTruthy();
	expect(command.allowsConcurrentExecution).to.beFalsy();
	expect(command.executing).to.beFalsy();
});

it(@"should pass the value along to subscribers", ^{
	__block id valueReceived = nil;
	[command subscribeNext:^(id value) {
		valueReceived = value;
	}];
	
	id sentValue = [NSNull null];
	expect([command execute:sentValue]).to.beTruthy();
	
	expect(valueReceived).to.equal(sentValue);
});

it(@"should not send anything on 'errors' by default", ^{
	__block BOOL receivedError = NO;
	[command.errors subscribeNext:^(id _) {
		receivedError = YES;
	}];
	
	expect([command execute:nil]).to.beTruthy();
	expect(receivedError).to.beFalsy();
});

it(@"should be executing from within the -execute: method", ^{
	[command subscribeNext:^(id _) {
		expect(command.executing).to.beTruthy();
	}];

	expect([command execute:nil]).to.beTruthy();
	expect(command.executing).to.beFalsy();
});

it(@"should dealloc without subscribers", ^{
	__block BOOL disposed = NO;

	@autoreleasepool {
		RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithCanExecuteSignal:nil];
		[command.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
			disposed = YES;
		}]];
	}

	expect(disposed).will.beTruthy();
});

it(@"should complete on the main thread when deallocated", ^{
	__block RACScheduler *completionScheduler = nil;

	[[RACScheduler scheduler] schedule:^{
		@autoreleasepool {
			RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithCanExecuteSignal:nil];
			[command subscribeCompleted:^{
				completionScheduler = RACScheduler.currentScheduler;
			}];
		}
	}];

	expect(completionScheduler).to.beNil();
	expect(completionScheduler).will.equal(RACScheduler.mainThreadScheduler);
});

it(@"should complete errors on the main thread when deallocated", ^{
	__block RACScheduler *completionScheduler = nil;

	[[RACScheduler scheduler] schedule:^{
		@autoreleasepool {
			RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithCanExecuteSignal:nil];
			[command.errors subscribeCompleted:^{
				completionScheduler = RACScheduler.currentScheduler;
			}];
		}
	}];

	expect(completionScheduler).to.beNil();
	expect(completionScheduler).will.equal(RACScheduler.mainThreadScheduler);
});

describe(@"with a signal block", ^{
	it(@"should invoke the signalBlock once per execution", ^{
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[command addActionBlock:^(id x) {
			[valuesReceived addObject:x];
			return [RACSignal empty];
		}];

		expect([command execute:@"foo"]).to.beTruthy();
		expect([command execute:@"bar"]).will.beTruthy();

		NSArray *expectedValues = @[ @"foo", @"bar" ];
		expect(valuesReceived).to.equal(expectedValues);
	});

	it(@"should return a signal of signals from -addActionBlock:", ^{
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[[[command
			addActionBlock:^(RACSequence *seq) {
				return [seq signalWithScheduler:RACScheduler.immediateScheduler];
			}]
			concat]
			subscribeNext:^(id x) {
				[valuesReceived addObject:x];
			}];

		RACSequence *first = @[ @"foo", @"bar" ].rac_sequence;
		expect([command execute:first]).to.beTruthy();

		RACSequence *second = @[ @"buzz", @"baz" ].rac_sequence;
		expect([command execute:second]).will.beTruthy();

		NSArray *expectedValues = @[ @"foo", @"bar", @"buzz", @"baz" ];
		expect(valuesReceived).to.equal(expectedValues);
	});

	it(@"should wait for all signals to complete or error before executing is set to NO", ^{
		RACSubject *first = [RACSubject subject];
		[command addActionBlock:^(id x) {
			return first;
		}];

		RACSubject *second = [RACSubject subject];
		[command addActionBlock:^(id x) {
			return second;
		}];

		expect([command execute:nil]).to.beTruthy();
		expect(command.executing).to.beTruthy();

		[first sendError:nil];
		expect(command.executing).to.beTruthy();

		[second sendNext:nil];
		expect(command.executing).to.beTruthy();

		[second sendCompleted];
		expect(command.executing).will.beFalsy();
	});

	it(@"should forward errors onto 'errors'", ^{
		NSError *firstError = [NSError errorWithDomain:@"" code:1 userInfo:nil];
		NSError *secondError = [NSError errorWithDomain:@"" code:2 userInfo:nil];
		
		NSMutableArray *receivedErrors = [NSMutableArray array];
		[command.errors subscribeNext:^(NSError *error) {
			[receivedErrors addObject:error];
		}];

		RACSubject *firstSubject = [RACSubject subject];
		[command addActionBlock:^(id _) {
			return firstSubject;
		}];

		RACSubject *secondSubject = [RACSubject subject];
		[command addActionBlock:^(id _) {
			return secondSubject;
		}];

		expect([command execute:nil]).to.beTruthy();
		expect(command.executing).to.beTruthy();

		[firstSubject sendError:firstError];
		expect(command.executing).to.beTruthy();

		NSArray *expected = @[ firstError ];
		expect(receivedErrors).will.equal(expected);

		[secondSubject sendError:secondError];
		expect(command.executing).will.beFalsy();

		expected = @[ firstError, secondError ];
		expect(receivedErrors).will.equal(expected);
	});

	it(@"should not forward other events onto 'errors'", ^{
		__block BOOL receivedEvent = NO;
		[command.errors subscribeNext:^(id _) {
			receivedEvent = YES;
		}];

		RACSubject *subject = [RACSubject subject];
		[command addActionBlock:^(id _) {
			return subject;
		}];

		expect([command execute:nil]).to.beTruthy();
		expect(command.executing).to.beTruthy();

		[subject sendNext:RACUnit.defaultUnit];
		[subject sendCompleted];

		expect(command.executing).will.beFalsy();
		expect(receivedEvent).to.beFalsy();
	});

	it(@"should not deliver errors to subscribers", ^{
		RACSubject *subject = [RACSubject subject];
		NSMutableArray *receivedEvents = [NSMutableArray array];

		[[[[command
			addActionBlock:^(id value) {
				return subject;
			}]
			flatten]
			materialize]
			subscribeNext:^(RACEvent *event) {
				[receivedEvents addObject:event];
			}];

		expect([command execute:nil]).to.beTruthy();
		expect(command.executing).to.beTruthy();

		[subject sendNext:RACUnit.defaultUnit];

		NSArray *expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit] ];
		expect(receivedEvents).to.equal(expectedEvents);
		expect(command.executing).to.beTruthy();

		[subject sendNext:@"foo"];

		expectedEvents = @[ [RACEvent eventWithValue:RACUnit.defaultUnit], [RACEvent eventWithValue:@"foo"] ];
		expect(receivedEvents).to.equal(expectedEvents);
		expect(command.executing).to.beTruthy();

		NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];
		[subject sendError:error];
		
		expect(command.executing).will.beFalsy();
		expect(receivedEvents).to.equal(expectedEvents);
	});

	it(@"should dealloc without subscribers", ^{
		__block BOOL disposed = NO;

		@autoreleasepool {
			RACCommand *command __attribute__((objc_precise_lifetime)) = [[RACCommand alloc] initWithCanExecuteSignal:nil];

			[command addActionBlock:^(id x) {
				return [RACSignal empty];
			}];

			[command.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				disposed = YES;
			}]];
		}

		expect(disposed).will.beTruthy();
	});
});

describe(@"canExecute property", ^{
	it(@"should be NO when the canExecuteSignal has sent NO most recently", ^{
		command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
		expect(command).notTo.beNil();
		expect(command.canExecute).to.beFalsy();
		
		command = [RACCommand commandWithCanExecuteSignal:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@YES];
			[subscriber sendNext:@NO];
			return nil;
		}]];
		
		expect(command.canExecute).to.beFalsy();
	});
	
	it(@"should be YES when the canExecuteSignal has sent YES most recently", ^{
		command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
		expect(command).notTo.beNil();
		expect(command.canExecute).to.beTruthy();
		
		command = [RACCommand commandWithCanExecuteSignal:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@NO];
			[subscriber sendNext:@YES];
			return nil;
		}]];
		
		expect(command.canExecute).to.beTruthy();
	});

	it(@"should be NO while executing is YES and allowsConcurrentExecution is NO", ^{
		[command subscribeNext:^(id _) {
			expect(command.executing).to.beTruthy();
			expect(command.canExecute).to.beFalsy();
		}];

		expect(command.canExecute).to.beTruthy();
		expect([command execute:nil]).to.beTruthy();
		expect(command.canExecute).to.beTruthy();
	});

	it(@"should be YES while executing is YES and allowsConcurrentExecution is YES", ^{
		command.allowsConcurrentExecution = YES;

		// Prevent infinite recursion by only responding to the first value.
		[[command take:1] subscribeNext:^(id _) {
			expect(command.executing).to.beTruthy();
			expect(command.canExecute).to.beTruthy();
			expect([command execute:nil]).to.beTruthy();
		}];

		expect(command.canExecute).to.beTruthy();
		expect([command execute:nil]).to.beTruthy();
		expect(command.canExecute).to.beTruthy();
	});

	it(@"should always update on the main thread", ^{
		RACSubject *subject = [RACSubject subject];

		command = [RACCommand commandWithCanExecuteSignal:subject];
		expect(command.canExecute).to.beTruthy();

		__block RACScheduler *updatedScheduler = nil;
		[RACAble(command, canExecute) subscribeNext:^(id _) {
			updatedScheduler = RACScheduler.currentScheduler;
		}];

		[[RACScheduler scheduler] schedule:^{
			[subject sendNext:@NO];
		}];

		expect(command.canExecute).to.beTruthy();
		expect(command.canExecute).will.beFalsy();
		expect(updatedScheduler).to.equal(RACScheduler.mainThreadScheduler);
	});
});

SpecEnd
