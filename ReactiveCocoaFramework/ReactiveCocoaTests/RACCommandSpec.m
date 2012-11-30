//
//  RACCommandSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 8/31/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"

SpecBegin(RACCommand)

describe(@"when it's created with a canExecute signal", ^{
	it(@"shouldn't be executable when its signal has sent NO most recently", ^{
		RACCommand *command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO] block:NULL];
		
		expect(command.canExecute).to.beFalsy();
		
		command = [RACCommand commandWithCanExecuteSignal:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@YES];
			[subscriber sendNext:@NO];
			return nil;
		}] block:NULL];
		
		expect(command.canExecute).to.beFalsy();
	});
	
	it(@"should be executable when its signal has sent YES most recently", ^{
		RACCommand *command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES] block:NULL];
		
		expect(command.canExecute).to.beTruthy();
		
		command = [RACCommand commandWithCanExecuteSignal:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@NO];
			[subscriber sendNext:@YES];
			return nil;
		}] block:NULL];
		
		expect(command.canExecute).to.beTruthy();
	});
});

it(@"should always be able to execute when its can execute signal is nil", ^{
	RACCommand *command = [RACCommand commandWithCanExecuteSignal:nil block:NULL];
	
	expect(command.canExecute).to.beTruthy();
});

it(@"should call its execution block when executed", ^{
	__block id valueReceived = nil;
	RACCommand *command = [RACCommand commandWithCanExecuteSignal:nil block:^(id value) {
		valueReceived = value;
	}];
	
	id sentValue = [NSNull null];
	[command execute:sentValue];
	
	expect(valueReceived).to.equal(sentValue);
});

SpecEnd
