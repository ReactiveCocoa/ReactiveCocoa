//
//  UIBarButtonItemRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 4/13/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlCommandExamples.h"

#import "UIBarButtonItem+RACCommandSupport.h"
#import "RACCommand.h"
#import "RACDisposable.h"

SpecBegin(UIBarButtonItemRACSupport)

describe(@"UIBarButtonItem", ^{
	__block UIBarButtonItem *button;
	
	beforeEach(^{
		button = [[UIBarButtonItem alloc] init];
		expect(button).notTo.beNil();
	});

	itShouldBehaveLike(RACControlCommandExamples, ^{
		return @{
			RACControlCommandExampleControl: button,
			RACControlCommandExampleActivateBlock: ^(UIBarButtonItem *button) {
				NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[button.target methodSignatureForSelector:button.action]];
				invocation.selector = button.action;

				id target = button.target;
				[invocation setArgument:&target atIndex:2];
				[invocation invokeWithTarget:target];
			}
		};
	});
});

SpecEnd
