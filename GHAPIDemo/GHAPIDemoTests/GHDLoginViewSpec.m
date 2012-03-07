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
		
		GHDRunRunLoop();
		
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"shouldn't allow you to login with only a password", ^{
		viewController.username = @"";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
		
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"shouldn't allow you to login without both a username and password", ^{
		viewController.username = @"";
		viewController.password = @"";
		
		GHDRunRunLoop();
		
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"should allow you to login with both a username and password", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
		
		expect(viewController.loginEnabled).toBeTruthy();
	});
	
	it(@"shouldn't allow you to login when login is executing", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
		
		[viewController.loginCommand execute:nil];
		
		GHDRunRunLoop();
		
		expect(viewController.loginEnabled).toBeFalsy();
	});
	
	it(@"should show login failure", ^{
		viewController.username = @"johnsmith";
		viewController.password = @"secret";
		
		GHDRunRunLoop();
				
		[viewController.loginCommand execute:nil];
		
		GHDRunRunLoop();
		
		expect(viewController.loginEnabled).toBeFalsy();
	});
});

SpecEnd
