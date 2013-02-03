//
//  RACSignalCommandSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalCommand.h"
#import "RACSignal+Operations.h"
#import "RACCommandExamples.h"

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

SpecEnd
