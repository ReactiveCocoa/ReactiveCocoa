//
//  RACSignalCommandSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalCommand.h"
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
});

SpecEnd
