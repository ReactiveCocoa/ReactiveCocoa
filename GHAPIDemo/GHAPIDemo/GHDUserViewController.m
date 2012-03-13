//
//  GHDUserViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDUserViewController.h"
#import "GHDUserView.h"
#import "GHUserAccount.h"
#import "GHGitHubClient.h"

@interface GHDUserViewController ()
@property (nonatomic, strong) GHDUserView *view;
@property (nonatomic, strong) GHUserAccount *userAccount;
@property (nonatomic, assign) BOOL loading;
@end


@implementation GHDUserViewController


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDUserView ghd_viewFromNib];

	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.userAccount.username)];
	[self.view.realNameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.userAccount.realName)];
	[self.view.spinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RACKVO(self.loading)];
	[self.view.usernameTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loading)];
	[self.view.realNameTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loading)];
}


#pragma mark API

@synthesize userAccount;
@dynamic view;
@synthesize loading;

- (id)initWithUserAccount:(GHUserAccount *)user {
	self = [super initWithNibName:nil bundle:nil];
	if(self == nil) return nil;
	
	RACSequence *userInfo = [[RACObservable(self.userAccount) where:^BOOL(id x) {
		return x != nil;
	}] selectMany:^(GHUserAccount *x) {
		return [[GHGitHubClient clientForUserAccount:x] fetchUserInfo];
	}];
	
	[RACObservable(self.userAccount) subscribeNext:^(id x) {
		self.loading = YES;
	}];

	[userInfo subscribeNext:^(id x) {
		self.loading = NO;
	} error:^(NSError *error) {
		self.loading = NO;
		NSLog(@"error: %@", error);
	}];
	
	[[[userInfo where:^(id x) {
		return [x hasObject];
	}] select:^(id x) {
		return [x object];
	}] subscribeNext:^(id x) {
		self.userAccount.realName = [x objectForKey:@"name"];
	}];
	
	self.userAccount = user;
	
	return self;
}

@end
