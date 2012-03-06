//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "GHDLoginView.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface GHDLoginViewController ()
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, assign) BOOL loginEnabled;
@property (nonatomic, strong) GHDLoginView *view;
@property (nonatomic, strong) RACValue *successHiddenValue;
@property (nonatomic, strong) RACValue *loginFailedHiddenValue;
@end


@implementation GHDLoginViewController


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView view];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.loginEnabled) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	[self.view.successTextField bind:NSHiddenBinding toValue:self.successHiddenValue];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toValue:self.loginFailedHiddenValue];
	
	[[[RACSequence 
		combineLatest:[NSArray arrayWithObjects:[self RACValueForKeyPath:RACKVO(self.username)], [self RACValueForKeyPath:RACKVO(self.password)], nil]]
		select:^(NSArray *x) { return [NSNumber numberWithBool:[[x objectAtIndex:0] length] > 0 && [[x objectAtIndex:1] length] > 0]; }] 
		toObject:self keyPath:RACKVO(self.loginEnabled)];
	
	RACAsyncCommand *loginCommand = [RACAsyncCommand commandWithCanExecute:^(id _) { return self.loginEnabled; } execute:NULL];
	
	__block BOOL didLoginLastTime = NO;
	RACValue *result = [loginCommand addAsyncFunction:^(id value, NSError **error) {
		NSLog(@"execute!");
		
		// TODO: actually attempt to auth
		
		[NSThread sleepForTimeInterval:5.0f];
		NSNumber *didLogin = [NSNumber numberWithBool:!didLoginLastTime];
		didLoginLastTime = !didLoginLastTime;
		return didLogin;
	}];
	[self.view.loginButton addCommand:loginCommand];
	
	[[[[[result 
		subscribeNext:^(id x) { NSLog(@"could login: %@", x); }] 
		select:^(id x) { return [NSNumber numberWithBool:![x boolValue]]; }]
		toSequence:self.successHiddenValue]
		select:^(id x) { return [NSNumber numberWithBool:![x boolValue]]; }] 
		toSequence:self.loginFailedHiddenValue];
	
	[[[[RACSequence 
		merge:[NSArray arrayWithObjects:[self RACValueForKeyPath:RACKVO(self.username)], [self RACValueForKeyPath:RACKVO(self.password)], nil]] 
		select:^(id _) { return [NSNumber numberWithBool:YES]; }]
		toSequence:self.successHiddenValue]
		toSequence:self.loginFailedHiddenValue];
}


#pragma mark API

@synthesize username;
@synthesize password;
@synthesize loginEnabled;
@dynamic view;
rac_synthesize_val(successHiddenValue, [NSNumber numberWithBool:YES]);
rac_synthesize_val(loginFailedHiddenValue, [NSNumber numberWithBool:YES]);

@end
