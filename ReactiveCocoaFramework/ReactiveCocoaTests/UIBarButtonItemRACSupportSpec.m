//
//  UIBarButtonItemRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 4/13/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"

#import "UIBarButtonItem+RACSupport.h"
#import "RACAction.h"
#import "RACDisposable.h"
#import "RACSignal.h"

SpecBegin(UIBarButtonItemRACSupport)

describe(@"UIBarButtonItem", ^{
	__block UIBarButtonItem *button;

	void (^activate)(UIBarButtonItem *) = ^(UIBarButtonItem *button) {
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[button.target methodSignatureForSelector:button.action]];
		invocation.selector = button.action;

		id sender = self;
		[invocation setArgument:&sender atIndex:2];
		[invocation invokeWithTarget:button];
	};
	
	beforeEach(^{
		button = [[UIBarButtonItem alloc] init];
		expect(button).notTo.beNil();
	});

	it(@"should send on rac_actionSignal", ^{
		RACSignal *actionSignal = button.rac_actionSignal;
		expect(button.target).to.beNil();
		expect(button.action).to.beNil();

		__block id value = nil;
		[actionSignal subscribeNext:^(id x) {
			value = x;
		}];

		expect(button.target).notTo.beNil();
		expect(button.action).notTo.beNil();
		expect(value).to.beNil();

		activate(button);
		expect(value).to.beIdenticalTo(button);
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: button,
			RACControlActionExampleActivateBlock: activate
		};
	});
});

SpecEnd
