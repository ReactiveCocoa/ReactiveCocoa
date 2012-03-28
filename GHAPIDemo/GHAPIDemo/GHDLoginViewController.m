//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "GHDLoginView.h"
#import "GHGitHubClient.h"
#import "GHGitHubUser.h"
#import "NSView+GHDExtensions.h"

@interface GHDLoginViewController ()
@property (nonatomic, assign) BOOL successHidden;
@property (nonatomic, assign) BOOL loginFailedHidden;
@property (nonatomic, assign) BOOL loginEnabled;
@property (nonatomic, assign) BOOL loggingIn;
@property (nonatomic, strong) RACAsyncCommand *loginCommand;
@property (nonatomic, strong) GHDLoginView *view;
@property (nonatomic, strong) GHGitHubUser *user;
@property (nonatomic, strong) GHGitHubClient *client;
@property (nonatomic, strong) RACSubject *didLoginSubject;
@end


@implementation GHDLoginViewController

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.loginFailedHidden = YES;
	self.successHidden = YES;
	self.loginEnabled = NO;
	self.loggingIn = NO;
	
	self.didLoginSubject = [RACSubject subject];
	
	[[RACSubscribable 
		combineLatest:[NSArray arrayWithObjects:RACProperty(self.username), RACProperty(self.password), RACProperty(self.loginCommand.numberOfActiveExecutions), nil] reduce:^(NSArray *xs) {
			return [NSNumber numberWithBool:[[xs objectAtIndex:0] length] > 0 && [[xs objectAtIndex:1] length] > 0 && [[xs objectAtIndex:2] unsignedIntegerValue] < 1];
		}] subscribeNext:^(id x) {
			self.loginEnabled = [x boolValue];
		}];
	
	self.loginCommand = [RACAsyncCommand command];
	[self.loginCommand 
		subscribeNext:^(id _) {
			self.user = [GHGitHubUser userWithUsername:self.username password:self.password];
			self.client = [GHGitHubClient clientForUser:self.user];
			self.loggingIn = YES;
		}];
	
	RACSubject *loginResult = [[[self.loginCommand addAsyncFunction:^(id _) { return [self.client login]; }] repeat] catchToMaybe];

	[[[loginResult 
		where:^(id x) { return [x hasError]; }] 
		select:^(id x) { return [x error]; }] 
		subscribeNext:^(id x) {
			self.loginFailedHidden = NO;
			NSLog(@"error logging in: %@", x);
		}];
	
	[[loginResult 
		where:^(id x) { return [x hasObject]; }]
		subscribeNext:^(id _) {
			self.successHidden = NO;
			[self.didLoginSubject sendNext:self.user];
		}];
	
	[loginResult subscribeNext:^(id x) { self.loggingIn = NO; }];
		
	[[RACSubscribable 
		merge:[NSArray arrayWithObjects:RACProperty(self.username), RACProperty(self.password), nil]] 
		subscribeNext:^(id _) { self.successHidden = self.loginFailedHidden = YES; }];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView ghd_viewFromNib];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password)];
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loginFailedHidden)];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.loginEnabled)];
	[self.view.loggingInSpinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RACKVO(self.loggingIn)];
	
	[self.view.loggingInSpinner startAnimation:nil];
	
	[self.view.loginButton addCommand:self.loginCommand];
}


#pragma mark API

@synthesize username;
@synthesize password;
@dynamic view;
@synthesize successHidden;
@synthesize loginFailedHidden;
@synthesize loginCommand;
@synthesize loginEnabled;
@synthesize loggingIn;
@synthesize user;
@synthesize client;
@synthesize didLoginSubject;

@end
