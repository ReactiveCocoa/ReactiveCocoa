//
//  RACCommandSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 8/31/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "NSArray+RACSequenceAdditions.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"

SpecBegin(RACCommand)

__block RACCommand *command;

beforeEach(^{
	command = [RACCommand command];
	expect(command).notTo.beNil();

	expect(command.canExecute).to.beTruthy();
	expect(command.allowsConcurrentExecution).to.beFalsy();
	expect(command.executing).to.beFalsy();
});

it(@"should pass the sender along to subscribers", ^{
	__block id valueReceived = nil;
	[command subscribeNext:^(id value) {
		valueReceived = value;
	}];
	
	id sentValue = [NSNull null];
	expect([command execute:sentValue]).to.beTruthy();
	
	expect(valueReceived).to.equal(sentValue);
});

it(@"should be executing from within the -execute: method", ^{
	[command subscribeNext:^(id _) {
		expect(command.executing).to.beTruthy();
	}];

	expect([command execute:nil]).to.beTruthy();
	expect(command.executing).to.beFalsy();
});

describe(@"with a signal block", ^{
	it(@"should invoke the signalBlock once per execution", ^{
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[command addSignalBlock:^(id x) {
			[valuesReceived addObject:x];
			return [RACSignal empty];
		}];

		expect([command execute:@"foo"]).to.beTruthy();
		expect([command execute:@"bar"]).to.beTruthy();

		NSArray *expectedValues = @[ @"foo", @"bar" ];
		expect(valuesReceived).to.equal(expectedValues);
	});

	it(@"should return a signal of signals from -addSignalBlock:", ^{
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[[[command
			addSignalBlock:^(RACSequence *seq) {
				return [seq signalWithScheduler:RACScheduler.immediateScheduler];
			}]
			concat]
			subscribeNext:^(id x) {
				[valuesReceived addObject:x];
			}];

		RACSequence *first = @[ @"foo", @"bar" ].rac_sequence;
		expect([command execute:first]).to.beTruthy();

		RACSequence *second = @[ @"buzz", @"baz" ].rac_sequence;
		expect([command execute:second]).to.beTruthy();

		NSArray *expectedValues = @[ @"foo", @"bar", @"buzz", @"baz" ];
		expect(valuesReceived).to.equal(expectedValues);
	});

	it(@"should wait for all signals to complete or error before executing is set to NO", ^{
		RACSubject *first = [RACSubject subject];
		[command addSignalBlock:^(id x) {
			return first;
		}];

		RACSubject *second = [RACSubject subject];
		[command addSignalBlock:^(id x) {
			return second;
		}];

		expect([command execute:nil]).to.beTruthy();
		expect(command.executing).to.beTruthy();

		[first sendError:nil];
		expect(command.executing).to.beTruthy();

		[second sendNext:nil];
		expect(command.executing).to.beTruthy();

		[second sendCompleted];
		expect(command.executing).to.beFalsy();
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
});

SpecEnd
