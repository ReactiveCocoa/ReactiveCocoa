//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
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
	
	// Login is only enabled when they've entered both a username and password,
	// and we aren't already trying to login.
	[[RACSubscribable 
		combineLatest:[NSArray arrayWithObjects:RACAbleSelf(self.username), RACAbleSelf(self.password), RACAbleSelf(self.loginCommand.numberOfActiveExecutions), nil] 
		reduce:^(RACTuple *xs) {
			return [NSNumber numberWithBool:[[xs objectAtIndex:0] length] > 0 && [[xs objectAtIndex:1] length] > 0 && [[xs objectAtIndex:2] unsignedIntegerValue] < 1];
		}]
		toProperty:RAC_KEYPATH_SELF(self.loginEnabled) onObject:self];
	
	self.loginCommand = [RACAsyncCommand command];
	__block __unsafe_unretained id weakSelf = self;
	[self.loginCommand subscribeNext:^(id _) {
		GHDLoginViewController *strongSelf = weakSelf;
		strongSelf.user = [GHGitHubUser userWithUsername:strongSelf.username password:strongSelf.password];
		strongSelf.client = [GHGitHubClient clientForUser:strongSelf.user];
		strongSelf.loggingIn = YES;
	}];
	
	// Note the -repeat and -asMaybes at the end. -repeat means that this
	// subscribable will resubscribe to its source right after it completes.
	// This lets us subscribe to the same subscribable even though the source
	// subscribable (the API call) completes. -asMaybes means that we wrap 
	// each next value or error in a RACMaybe. This means that even if the 
	// API hits an error, the subscribable will still be valid.
	RACSubscribable *loginResult = [[[self.loginCommand 
		addAsyncBlock:^(id _) {
			GHDLoginViewController *strongSelf = weakSelf;
			return [strongSelf.client login];
		}]
		repeat]
		asMaybes];

	// Since we used -asMaybes above, we'll need to filter out the specific
	// error or success cases.
	[[[loginResult 
		where:^(id x) {
			return [x hasError];
		}] 
		select:^(id x) {
			return [x error];
		}] 
		subscribeNext:^(id x) {
			GHDLoginViewController *strongSelf = weakSelf;
			strongSelf.loginFailedHidden = NO;
			NSLog(@"error logging in: %@", x);
		}];
	
	[[loginResult 
		where:^(id x) {
			return [x hasObject];
		}]
		subscribeNext:^(id _) {
			GHDLoginViewController *strongSelf = weakSelf;
			strongSelf.successHidden = NO;
			[strongSelf.didLoginSubject sendNext:strongSelf.user];
		}];
	
	[loginResult subscribeNext:^(id x) {
		GHDLoginViewController *strongSelf = weakSelf;
		strongSelf.loggingIn = NO;
	}];
	
	// When either username or password change, hide the success or failure
	// message.
	[[RACSubscribable 
		merge:[NSArray arrayWithObjects:RACAbleSelf(self.username), RACAbleSelf(self.password), nil]] 
		subscribeNext:^(id _) {
			GHDLoginViewController *strongSelf = weakSelf;
			strongSelf.successHidden = strongSelf.loginFailedHidden = YES;
		}];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView ghd_viewFromNib];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.password)];
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.loginFailedHidden)];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.loginEnabled)];
	[self.view.loggingInSpinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RAC_KEYPATH_SELF(self.loggingIn)];
	
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
