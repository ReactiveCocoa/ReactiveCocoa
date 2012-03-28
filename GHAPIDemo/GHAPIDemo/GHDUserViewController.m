//
//  GHDUserViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDUserViewController.h"
#import "GHDUserView.h"
#import "GHGitHubUser.h"
#import "GHGitHubClient.h"
#import "NSView+GHDExtensions.h"

@interface GHDUserViewController ()
@property (nonatomic, strong) GHDUserView *view;
@property (nonatomic, strong) GHGitHubUser *userAccount;
@property (nonatomic, assign) BOOL loading;
@end


@implementation GHDUserViewController


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDUserView ghd_viewFromNib];
	
	[self.view.spinner startAnimation:nil];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.userAccount.username)];
	[self.view.realNameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.userAccount.realName)];
	[self.view.spinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RACKVO(self.loading)];
	[self.view.valuesContainerView bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loading)];
}


#pragma mark API

@synthesize userAccount;
@dynamic view;
@synthesize loading;

- (id)initWithUserAccount:(GHGitHubUser *)user {
	self = [super initWithNibName:nil bundle:nil];
	if(self == nil) return nil;
	
	self.loading = YES;
	
	RACSubscribable *userAccountIsntNil = [RACProperty(self.userAccount) where:^BOOL(id x) { return x != nil; }];
	[userAccountIsntNil subscribeNext:^(id _) { self.loading = YES; }];
	
	RACSubscribable *userInfo = [userAccountIsntNil selectMany:^(GHGitHubUser *x) { return [[GHGitHubClient clientForUser:x] fetchUserInfo]; }];
	[userInfo subscribeNext:^(id _) { self.loading = NO; }];
	
	[[[userInfo 
		where:^(id x) { return [x hasError]; }] 
		select:^(id x) { return [x error]; }] 
		subscribeNext:^(id x) { NSLog(@"error: %@", x); }];
	
	[[[userInfo 
		where:^(id x) { return [x hasObject]; }] 
		select:^(id x) { return [x object]; }] 
		subscribeNext:^(id x) { [self.userAccount setValuesForKeysWithDictionary:x]; }];
	
	self.userAccount = user;
	
	return self;
}

@end
