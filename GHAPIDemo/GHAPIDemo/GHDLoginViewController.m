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
#import "GHJSONRequestOperation.h"

@interface GHDLoginViewController ()
@property (nonatomic, assign) BOOL successHidden;
@property (nonatomic, assign) BOOL loginFailedHidden;
@property (nonatomic, assign) BOOL loginEnabled;
@property (nonatomic, assign) BOOL loggingIn;
@property (nonatomic, strong) RACAsyncCommand *loginCommand;
@property (nonatomic, strong) GHDLoginView *view;
@end


@implementation GHDLoginViewController

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.loginFailedHidden = YES;
	self.successHidden = YES;
	self.loginEnabled = NO;
	self.loggingIn = NO;
	
	self.loginCommand = [RACAsyncCommand command];
	
	[[[RACSequence 
		combineLatest:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), self.loginCommand.canExecuteValue, nil]]
		select:^(NSArray *x) { return [NSNumber numberWithBool:[[x objectAtIndex:0] length] > 0 && [[x objectAtIndex:1] length] > 0 && [[x objectAtIndex:2] boolValue]]; }] 
		toObject:self keyPath:RACKVO(self.loginEnabled)];
	
	RACValue *result = [self.loginCommand addOperationBlock:^{
		[[GHGitHubClient sharedClient] setAuthorizationHeaderWithUsername:self.username password:self.password];
		
		NSURLRequest *request = [[GHGitHubClient sharedClient] requestWithMethod:@"GET" path:@"" parameters:nil];
		return [[GHGitHubClient sharedClient] HTTPRequestOperationWithRequest:request];
	}];
	
	[result subscribeNext:^(id x) {
		self.successHidden = NO;
		self.loginFailedHidden = YES;
	}];
	
	[result subscribeError:^(NSError *error) {
		self.successHidden = YES;
		self.loginFailedHidden = NO;
		NSLog(@"error: %@", error);
	}];
	
	[self.loginCommand subscribeNext:^(id _) { self.loggingIn = YES; }];
	[result subscribeCompleted:^{ self.loggingIn = NO; }];
	
	[[RACSequence 
		merge:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), nil]] 
		subscribeNext:^(id _) { self.successHidden = self.loginFailedHidden = YES; }];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView view];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password)];
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loginFailedHidden)];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.loginEnabled)];
	[self.view.loggingInSpinner bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loggingIn) options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
	
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

@end
