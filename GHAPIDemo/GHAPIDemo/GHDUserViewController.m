//
//  GHDUserViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDUserViewController.h"
#import "GHDUserView.h"
#import "GHGitHubUser.h"
#import "GHGitHubClient.h"
#import "NSView+GHDExtensions.h"

@interface GHDUserViewController ()
@property (nonatomic, strong) GHDUserView *view;
@property (nonatomic, strong) GHGitHubUser *userAccount;
@property (nonatomic, strong) NSImage *avatar;
@property (nonatomic, assign) BOOL loading;
@end


@implementation GHDUserViewController


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDUserView ghd_viewFromNib];
	
	[self.view.spinner startAnimation:nil];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.userAccount.username)];
	[self.view.realNameTextField bind:NSValueBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.userAccount.realName)];
	[self.view.spinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RAC_KEYPATH_SELF(self.loading)];
	[self.view.valuesContainerView bind:NSHiddenBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.loading)];
	[self.view.avatarImageView bind:NSValueBinding toObject:self withKeyPath:RAC_KEYPATH_SELF(self.avatar)];
}


#pragma mark API

@synthesize userAccount;
@dynamic view;
@synthesize loading;
@synthesize avatar;

- (id)initWithUserAccount:(GHGitHubUser *)user {
	self = [super initWithNibName:nil bundle:nil];
	if(self == nil) return nil;
		
	RACSubscribable *userAccountIsntNil = [RACAbleSelf(self.userAccount) where:^BOOL(id x) {
		return x != nil;
	}];
	
	[[[userAccountIsntNil 
		injectObjectWeakly:self]
		select:^id(id x) {
			return [NSNumber numberWithBool:YES];
		}]
		toProperty:RAC_KEYPATH_SELF(self.loading) onObject:self];
	
	// We're using -selectMany: to chain userAccountIsntNil so that we fetch
	// the new user account's info whenever it changes.
	[[userAccountIsntNil 
		selectMany:^(GHGitHubUser *x) {
			return [[GHGitHubClient clientForUser:x] fetchUserInfo];
		}]
		subscribeNext:^(id x) {
			GHDUserViewController *strongSelf = weakSelf;
			[strongSelf.userAccount setValuesForKeysWithDictionary:x];
			strongSelf.loading = NO;
		}
		error:^(NSError *error) {
			NSLog(@"error: %@", error);
			GHDUserViewController *strongSelf = weakSelf;
			strongSelf.loading = NO;
		}];
	
	// Note that we're using -deliverOn: to load the image in a background 
	// queue and then finish with another -deliverOn: so that subscribers get 
	// the result on the main queue.
	RACSubscribable *loadedAvatar = [[[[[RACAbleSelf(self.userAccount.avatarURL) 
		where:^BOOL(id x) {
			return x != nil;
		}] 
		deliverOn:[RACScheduler sharedOperationQueueScheduler]] 
		select:^(id x) {
			return [[NSImage alloc] initWithContentsOfURL:x];
		}] 
		where:^BOOL(id x) {
			return x != nil;
		}]
		deliverOn:[RACScheduler mainQueueScheduler]];
	
	// -merge: takes the latest value from the subscribables. In this case, 
	// we're using -[RACSubscribable return:] to make a subscribable that 
	// immediately sends the default image, and will use the loaded avatar when
	// it loads.
	[[RACSubscribable 
		merge:[NSArray arrayWithObjects:[RACSubscribable return:[NSImage imageNamed:NSImageNameUser]], loadedAvatar, nil]] 
		toProperty:RAC_KEYPATH_SELF(self.avatar) onObject:self];
	
	self.userAccount = user;
	
	return self;
}

@end
