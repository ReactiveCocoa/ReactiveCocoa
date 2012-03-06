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
@property (nonatomic, assign) BOOL successHidden;
@property (nonatomic, assign) BOOL loginFailedHidden;
@property (nonatomic, strong) RACAsyncCommand *loginCommand;
@property (nonatomic, strong) GHDLoginView *view;
@end


@implementation GHDLoginViewController

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.loginFailedHidden = YES;
	self.successHidden = YES;
	
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
		combineLatest:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), nil]]
		select:^(NSArray *x) { return [NSNumber numberWithBool:[[x objectAtIndex:0] length] > 0 && [[x objectAtIndex:1] length] > 0]; }] 
		toSequence:self.loginCommand.canExecuteValue];
	
	[[[[[result 
		subscribeNext:^(id x) { NSLog(@"could login: %@", x); }] 
		select:^(id x) { return [NSNumber numberWithBool:![x boolValue]]; }]
		toObject:self keyPath:RACKVO(self.successHidden)]
		select:^(id x) { return [NSNumber numberWithBool:![x boolValue]]; }] 
		toObject:self keyPath:RACKVO(self.loginFailedHidden)];
	
	[[[[RACSequence 
		merge:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), nil]] 
		select:^(id _) { return [NSNumber numberWithBool:YES]; }]
		toObject:self keyPath:RACKVO(self.successHidden)]
		toObject:self keyPath:RACKVO(self.loginFailedHidden)];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView view];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password)];
	
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loginFailedHidden)];
	
	[self.view.loginButton addCommand:self.loginCommand];
}


#pragma mark API

@synthesize username;
@synthesize password;
@dynamic view;
@synthesize successHidden;
@synthesize loginFailedHidden;
@synthesize loginCommand;

@end
