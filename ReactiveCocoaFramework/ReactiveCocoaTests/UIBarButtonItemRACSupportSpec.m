//
//  UIBarButtonItemRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Kyle LeNeau on 4/13/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"

#import "UIBarButtonItem+RACSupport.h"
#import "RACDisposable.h"

SpecBegin(UIBarButtonItemRACSupport)

describe(@"UIBarButtonItem", ^{
	__block UIBarButtonItem *button;
	
	beforeEach(^{
		button = [[UIBarButtonItem alloc] init];
		expect(button).notTo.beNil();
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: button,
			RACControlActionExampleActivateBlock: ^(UIBarButtonItem *button) {
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
