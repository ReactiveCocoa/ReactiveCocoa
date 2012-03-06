//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "GHDLoginView.h"

@interface GHDLoginViewController ()
@property (nonatomic, strong) GHDLoginView *view;
@end


@implementation GHDLoginViewController

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.loginCommand = [RACAsyncCommand command];
	self.loginCommand.canExecuteValue = [RACValue valueWithValue:[NSNumber numberWithBool:NO]];
	
	__block BOOL didLoginLastTime = NO;
	RACValue *result = [self.loginCommand addAsyncFunction:^(id value, NSError **error) {
		NSLog(@"execute!");
		
		// TODO: actually attempt to auth
		
		[NSThread sleepForTimeInterval:5.0f];
		NSNumber *didLogin = [NSNumber numberWithBool:!didLoginLastTime];
		didLoginLastTime = !didLoginLastTime;
		return didLogin;
	}];
	
	[[[RACSequence 
		combineLatest:[NSArray arrayWithObjects:[self RACValueForKeyPath:RACKVO(self.username)], [self RACValueForKeyPath:RACKVO(self.password)], nil]]
		select:^(NSArray *x) { return [NSNumber numberWithBool:[[x objectAtIndex:0] length] > 0 && [[x objectAtIndex:1] length] > 0]; }] 
		toSequence:self.loginCommand.canExecuteValue];
	
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
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView view];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	[self.view.successTextField bind:NSHiddenBinding toValue:self.successHiddenValue];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toValue:self.loginFailedHiddenValue];
	
	[self.view.loginButton addCommand:self.loginCommand];
}


#pragma mark API

@synthesize username;
@synthesize password;
@dynamic view;
rac_synthesize_val(successHiddenValue, [NSNumber numberWithBool:YES]);
rac_synthesize_val(loginFailedHiddenValue, [NSNumber numberWithBool:YES]);
@synthesize loginCommand;

@end
