//
//  RACCommandExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACCommandExamples.h"
#import "RACCommand.h"

NSString * const RACCommandExamples = @"RACCommandExamples";
NSString * const RACCommandExamplesClass = @"RACCommandExamplesClass";

SharedExampleGroupsBegin(RACCommandExamples)

sharedExamplesFor(RACCommandExamples, ^(NSDictionary *data) {
	__block Class commandClass;

	beforeEach(^{
		commandClass = data[RACCommandExamplesClass];
	});

	describe(@"when it's created with a canExecute signal", ^{
		it(@"shouldn't be executable when its signal has sent NO most recently", ^{
			RACCommand *command = [commandClass commandWithCanExecuteSignal:[RACSignal return:@NO] block:NULL];
			
			expect(command.canExecute).to.beFalsy();
			
			command = [commandClass commandWithCanExecuteSignal:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
				[subscriber sendNext:@YES];
				[subscriber sendNext:@NO];
				return nil;
			}] block:NULL];
			
			expect(command.canExecute).to.beFalsy();
		});
		
		it(@"should be executable when its signal has sent YES most recently", ^{
			RACCommand *command = [commandClass commandWithCanExecuteSignal:[RACSignal return:@YES] block:NULL];
			
			expect(command.canExecute).to.beTruthy();
			
			command = [commandClass commandWithCanExecuteSignal:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
				[subscriber sendNext:@NO];
				[subscriber sendNext:@YES];
				return nil;
			}] block:NULL];
			
			expect(command.canExecute).to.beTruthy();
		});
	});

	it(@"should always be able to execute when its can execute signal is nil", ^{
		RACCommand *command = [commandClass commandWithCanExecuteSignal:nil block:NULL];
		
		expect(command.canExecute).to.beTruthy();
	});

	it(@"should call its execution block when executed", ^{
		__block id valueReceived = nil;
		RACCommand *command = [commandClass commandWithCanExecuteSignal:nil block:^(id value) {
			valueReceived = value;
		}];
		
		id sentValue = [NSNull null];
		[command execute:sentValue];
		
		expect(valueReceived).to.equal(sentValue);
	});
});

SharedExampleGroupsEnd
