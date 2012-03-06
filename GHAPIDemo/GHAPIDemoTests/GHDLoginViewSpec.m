//
//  GHDLoginViewSpec.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#define EXP_SHORTHAND
#import "Specta.h"
#import "Expecta.h"

#import "GHDLoginViewController.h"


SpecBegin(LoginViewSpec)

describe(@"validation", ^{
	__block GHDLoginViewController *viewController = nil;
	
	void (^runRunLoop)(void) = ^{
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];
	};
	
	beforeEach(^{
		viewController = [[GHDLoginViewController alloc] init];
	});
	
	it(@"shouldn't allow you to login with only a username", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"";
		
		runRunLoop();
		
		expect([viewController.loginCommand canExecute:nil]).toBeFalsy();
	});
	
	it(@"shouldn't allow you to login with only a password", ^{
		viewController.username = @"";
		viewController.password = @"secret";
		
		runRunLoop();
		
		expect([viewController.loginCommand canExecute:nil]).toBeFalsy();
	});
	
	it(@"shouldn't allow you to login without both a username and password", ^{
		viewController.username = @"";
		viewController.password = @"";
		
		runRunLoop();
		
		expect([viewController.loginCommand canExecute:nil]).toBeFalsy();
	});
	
	it(@"should allow you to login with both a username and password", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		runRunLoop();
		
		expect([viewController.loginCommand canExecute:nil]).toBeTruthy();
	});
});

SpecEnd
