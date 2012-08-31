//
//  RACCommandSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 8/31/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACCommand.h"

SpecBegin(RACCommand)

describe(@"when it's created with a canExecute subscribable", ^{
	it(@"shouldn't be executable when its subscribable has sent NO most recently", ^{
		RACCommand *command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable return:@NO] execute:NULL];
		
		expect(command.canExecute).to.beFalsy();
		expect([command executeIfAllowed:nil]).to.beFalsy();
		
		command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@YES];
			[subscriber sendNext:@NO];
			return nil;
		}] execute:NULL];
		
		expect(command.canExecute).to.beFalsy();
		expect([command executeIfAllowed:nil]).to.beFalsy();
	});
	
	it(@"should be executable when its subscribable has sent YES most recently", ^{
		RACCommand *command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable return:@YES] execute:NULL];
		
		expect(command.canExecute).to.beTruthy();
		expect([command executeIfAllowed:nil]).to.beTruthy();
		
		command = [RACCommand commandWithCanExecuteSubscribable:[RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> subscriber) {
			[subscriber sendNext:@NO];
			[subscriber sendNext:@YES];
			return nil;
		}] execute:NULL];
		
		expect(command.canExecute).to.beTruthy();
		expect([command executeIfAllowed:nil]).to.beTruthy();
	});
	
	it(@"should always be executable when its block is NULL", ^{
		RACCommand *command = [RACCommand commandWithCanExecute:NULL execute:NULL];
		
		expect(command.canExecute).to.beTruthy();
		expect([command executeIfAllowed:nil]).to.beTruthy();
	});
});

describe(@"when it's created with a canExecute block", ^{
	it(@"shouldn't be executable when its block returns NO", ^{
		RACCommand *command = [RACCommand commandWithCanExecute:^(id value) {
			return NO;
		} execute:NULL];
		
		expect([command canExecute:nil]).to.beFalsy();
		expect([command executeIfAllowed:nil]).to.beFalsy();
	});
	
	it(@"should be executable when its block returns YES", ^{
		RACCommand *command = [RACCommand commandWithCanExecute:^(id value) {
			return YES;
		} execute:NULL];
		
		expect([command canExecute:nil]).to.beTruthy();
		expect([command executeIfAllowed:nil]).to.beTruthy();
	});
	
	it(@"should always be executable when its block is NULL", ^{
		RACCommand *command = [RACCommand commandWithCanExecute:NULL execute:NULL];
		
		expect([command canExecute:nil]).to.beTruthy();
		expect([command executeIfAllowed:nil]).to.beTruthy();
	});
});

it(@"should call its execution block when executed", ^{
	__block id valueReceived = nil;
	RACCommand *command = [RACCommand commandWithCanExecute:NULL execute:^(id value) {
		valueReceived = value;
	}];
	
	id sentValue = [NSNull null];
	[command execute:sentValue];
	
	expect(valueReceived).to.equal(sentValue);
});

SpecEnd
