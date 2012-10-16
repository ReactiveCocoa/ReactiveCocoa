//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "EXTKeyPathCoding.h"
#import "GHDLoginView.h"
#import "GHGitHubClient.h"
#import "GHGitHubUser.h"
#import "NSView+GHDExtensions.h"

@interface GHDLoginViewController ()
@property (nonatomic, assign) BOOL successHidden;
@property (nonatomic, assign) BOOL loginFailedHidden;
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
	self.loggingIn = NO;
	
	self.didLoginSubject = [RACSubject subject];
	
	[RACAble(self.loginCommand.numberOfActiveExecutions) subscribeNext:^(id x) {
		NSLog(@"Active requests: %@", x);
	}];
	
	// Login is only enabled when they've entered both a username and password.
	self.loginCommand = [RACAsyncCommand commandWithCanExecuteSubscribable:[RACSubscribable
		combineLatest:@[ RACAbleWithStart(self.username), RACAbleWithStart(self.password) ]
		reduce:^(RACTuple *xs) {
			return @([[xs objectAtIndex:0] length] > 0 && [[xs objectAtIndex:1] length] > 0);
		}]
		block:NULL];
	
	[[self.loginCommand 
		injectObjectWeakly:self] 
		subscribeNext:^(RACTuple *t) {
			GHDLoginViewController *self = t.last;
			self.user = [GHGitHubUser userWithUsername:self.username password:self.password];
			self.client = [GHGitHubClient clientForUser:self.user];
			self.loggingIn = YES;
		}];
	
	__block __unsafe_unretained id weakSelf = self;
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
		asMaybes] 
		repeat];

	// Since we used -asMaybes above, we'll need to filter out the specific
	// error or success cases.
	[[[[loginResult 
		where:^(id x) {
			return [x hasError];
		}] 
		select:^(id x) {
			return [x error];
		}] 
		injectObjectWeakly:self]
		subscribeNext:^(RACTuple *t) {
			GHDLoginViewController *self = t.last;
			self.loginFailedHidden = NO;
			NSLog(@"error logging in: %@", t.first);
		}];
	
	[[[loginResult 
		where:^(id x) {
			return [x hasObject];
		}]
		injectObjectWeakly:self]
		subscribeNext:^(RACTuple *t) {
			GHDLoginViewController *self = t.last;
			self.successHidden = NO;
			[self.didLoginSubject sendNext:self.user];
		}];
	
	[[loginResult 
		select:^id(id x) {
			return [NSNumber numberWithBool:NO];
		}] 
		toProperty:@keypath(self.loggingIn) onObject:self];
	
	// When either username or password change, hide the success or failure
	// message.
	[[[self 
		rac_whenAny:[NSArray arrayWithObjects:@keypath(self.username), @keypath(self.password), nil] 
		reduce:^id(RACTuple *xs) {
			return xs;
		}] 
		injectObjectWeakly:self] 
		subscribeNext:^(RACTuple *t) {
			GHDLoginViewController *self = t.last;
			self.successHidden = self.loginFailedHidden = YES;
		}];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView ghd_viewFromNib];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:@keypath(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:@keypath(self.password)];
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:@keypath(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:@keypath(self.loginFailedHidden)];
	[self.view.loggingInSpinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:@keypath(self.loggingIn)];
	
	[self.view.loggingInSpinner startAnimation:nil];
	
	self.view.loginButton.rac_command = self.loginCommand;
}


#pragma mark API

@synthesize username;
@synthesize password;
@dynamic view;
@synthesize successHidden;
@synthesize loginFailedHidden;
@synthesize loginCommand;
@synthesize loggingIn;
@synthesize user;
@synthesize client;
@synthesize didLoginSubject;

@end
