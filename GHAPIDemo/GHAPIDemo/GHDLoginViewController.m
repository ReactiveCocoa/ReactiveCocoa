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
@end


@implementation GHDLoginViewController


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView view];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.loginEnabled) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.view.successTextField bind:NSHiddenBinding toValue:self.successHiddenValue];
	
	[[[RACSequence 
		combineLatest:[NSArray arrayWithObjects:[self RACValueForKeyPath:RACKVO(self.username)], [self RACValueForKeyPath:RACKVO(self.password)], nil]]
		select:^(NSArray *x) { return [NSNumber numberWithBool:[[x objectAtIndex:0] length] > 0 && [[x objectAtIndex:1] length] > 0]; }] 
		subscribeNext:^(id x) { self.loginEnabled = [x boolValue]; }];
	
	RACAsyncCommand *loginCommand = [RACAsyncCommand commandWithCanExecute:^(id _) { return self.loginEnabled; } execute:NULL];
	RACSequence *result = [loginCommand addAsyncFunction:^(id value, NSError **error) {
		NSLog(@"fired!");
		
		// TODO: actually attempt to auth
		
		[NSThread sleepForTimeInterval:5.0f];
		return [NSNumber numberWithBool:YES];
	}];
	[self.view.loginButton addCommand:loginCommand];
	
	[[[result 
		subscribeNext:^(id x) { NSLog(@"could login: %@", x); }] 
		select:^(id x) { return [NSNumber numberWithBool:![x boolValue]]; }]
		toProperty:self.successHiddenValue];
	
	[[RACSequence 
		merge:[NSArray arrayWithObjects:[self RACValueForKeyPath:RACKVO(self.username)], [self RACValueForKeyPath:RACKVO(self.password)], nil]] 
		subscribeNext:^(id x) { self.successHiddenValue.value = [NSNumber numberWithBool:YES]; }];
}


#pragma mark API

@synthesize username;
@synthesize password;
@synthesize loginEnabled;
@dynamic view;
rac_synthesize_val(successHiddenValue, [NSNumber numberWithBool:YES]);

@end
