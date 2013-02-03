//
//  RACSignalCommandSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCommandExamples.h"

#import "RACSignalCommand.h"
#import "RACSignal+Operations.h"
#import "RACUnit.h"

SpecBegin(RACSignalCommand)

itShouldBehaveLike(RACCommandExamples, @{ RACCommandExamplesClass: RACSignalCommand.class });

describe(@"without a signal block", ^{
	__block RACSignalCommand *command;

	beforeEach(^{
		command = [RACSignalCommand command];
	});

	it(@"should set 'executing' to YES and 'canExecute' to NO while in -execute:", ^{
		expect(command.executing).to.beFalsy();
		expect(command.canExecute).to.beTruthy();

		[command subscribeNext:^(id sender) {
			expect(command.executing).to.beTruthy();
			expect(command.canExecute).to.beFalsy();
			expect([command execute:nil]).to.beFalsy();
		}];

		expect([command execute:nil]).to.beTruthy();
		expect(command.executing).to.beFalsy();
		expect(command.canExecute).to.beTruthy();
	});

	it(@"should not send on signalBlockSignal", ^{
		__block BOOL gotEvent = NO;
		[[command.signalBlockSignal materialize] subscribeNext:^(id x) {
			gotEvent = YES;
		}];

		expect([command execute:nil]).to.beTruthy();
		expect(gotEvent).to.beFalsy();
	});
});

it(@"should forward nexts from the returned signal", ^{
	RACSignalCommand *command = [RACSignalCommand commandWithSignalBlock:^(id sender) {
		return [[RACSignal return:sender] concat:[RACSignal return:RACUnit.defaultUnit]];
	}];

	NSMutableArray *valuesReceived = [NSMutableArray array];
	[command subscribeNext:^(id x) {
		[valuesReceived addObject:x ?: NSNull.null];
	}];

	expect([command execute:nil]).to.beTruthy();

	NSArray *expected = @[ NSNull.null, RACUnit.defaultUnit ];
	expect(valuesReceived).to.equal(expected);

	expect([command execute:@"foobar"]).to.beTruthy();

	expected = @[ NSNull.null, RACUnit.defaultUnit, @"foobar", RACUnit.defaultUnit ];
	expect(valuesReceived).to.equal(expected);
});

it(@"should forward errors from the returned signal", ^{
	RACSignalCommand *command = [RACSignalCommand commandWithSignalBlock:^(id sender) {
		return [RACSignal error:nil];
	}];

	__block BOOL gotError = NO;
	[command subscribeError:^(NSError *error) {
		gotError = YES;
	}];

	expect([command execute:nil]).to.beTruthy();
	expect(gotError).to.beTruthy();

	// The command should still be able to execute again.
	expect(command.canExecute).to.beTruthy();
});

it(@"should send on signalBlockSignal", ^{
	RACSignalCommand *command = [RACSignalCommand commandWithSignalBlock:^(id sender) {
		return [RACSignal empty];
	}];

	__block BOOL gotNext = NO;
	[command.signalBlockSignal subscribeNext:^(RACSignal *signal) {
		expect(signal).to.beKindOf(RACSignal.class);
		gotNext = YES;
	}];

	expect([command execute:nil]).to.beTruthy();
	expect(gotNext).to.beTruthy();
});

SpecEnd
