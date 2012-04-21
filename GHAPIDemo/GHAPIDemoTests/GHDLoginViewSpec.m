//
//  GHDLoginViewSpec.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#define EXP_SHORTHAND
#import "Specta.h"
#import "Expecta.h"
#import "GHDTestHelpers.h"

#import "GHDLoginViewController.h"


SpecBegin(LoginViewSpec)

describe(@"validation", ^{
	__block GHDLoginViewController *viewController = nil;
	
	beforeEach(^{
		viewController = [[GHDLoginViewController alloc] init];
	});
	
	it(@"shouldn't allow you to login with only a username", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"";
				
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"shouldn't allow you to login with only a password", ^{
		viewController.username = @"";
		viewController.password = @"secret";
				
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"shouldn't allow you to login without both a username and password", ^{
		viewController.username = @"";
		viewController.password = @"";
				
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"should allow you to login with both a username and password", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
				
		expect(viewController.loginEnabled).toBeTruthy();
	});
	
	it(@"shouldn't allow you to login when login is executing", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
		
		[viewController.loginCommand execute:nil];
				
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"should set loggingIn when it's logging in", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
		
		[viewController.loginCommand execute:nil];
				
		expect(viewController.loggingIn).toBeTruthy();
	});
	
	it(@"should show the login failed message when login fails", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
		
		[viewController.loginCommand execute:nil];
		
		GHDRunRunLoopWhile(^{ return viewController.loggingIn; });

		expect(viewController.loginFailedHidden).toBeFalsy();
	});
});

SpecEnd
