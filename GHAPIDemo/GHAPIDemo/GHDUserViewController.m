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
@property (nonatomic, strong) GHGitHubClient *client;
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
@synthesize client;

- (id)initWithUserAccount:(GHGitHubUser *)user {
	NSParameterAssert(user != nil);
	
	self = [super initWithNibName:nil bundle:nil];
	if(self == nil) return nil;
	
	self.userAccount = user;
	self.client = [GHGitHubClient clientForUser:self.userAccount];
	self.loading = YES;
	
	__block __unsafe_unretained id weakSelf = self;
	// We're using -merge: so that -fetchUser, -fetchRepos, and -fetchOrgs are 
	// all executed independently. We're then told when they've all completed.
	// -finally: lets us share logic regardless of whether we get an error or 
	// complete successfully.
	[[[RACSubscribable 
		merge:[NSArray arrayWithObjects:[self fetchUser], [self fetchRepos], [self fetchOrgs], nil]] 
		finally:^{
			GHDUserViewController *strongSelf = weakSelf;
			strongSelf.loading = NO;
		}]
		subscribeNext:^(id x) {
			// nothing
		} error:^(NSError *error) {
			NSLog(@"error: %@", error);
		} completed:^{
			NSLog(@"done");
		}];
	
	// We're using -deliverOn: to load the image in a background queue and then 
	// finish with another -deliverOn: so that subscribers get the result on the 
	// main queue.
	RACSubscribable *loadedAvatar = [[[[[RACAble(self.userAccount.avatarURL) 
		where:^BOOL(id x) {
			return x != nil;
		}] 
		deliverOn:[RACScheduler sharedOperationQueueScheduler]] 
		injectObjectWeakly:self]
		selectMany:^(RACTuple *t) {
			GHDUserViewController *self = t.last;
			return [self loadImageAtURL:t.first];
		}] 
		deliverOn:[RACScheduler mainQueueScheduler]];
	
	// -merge: takes the latest value from the subscribables. In this case, 
	// we're using -[RACSubscribable return:] to make a subscribable that 
	// immediately sends the default image, and will use the loaded avatar when
	// it loads.
	[[RACSubscribable 
		merge:[NSArray arrayWithObjects:[RACSubscribable return:[NSImage imageNamed:NSImageNameUser]], loadedAvatar, nil]] 
		toProperty:RAC_KEYPATH_SELF(self.avatar) onObject:self];
	
	return self;
}

- (RACSubscribable *)fetchUser {	
	return [[[self.client 
				fetchUserInfo] 
				injectObjectWeakly:self]
				select:^(RACTuple *t) {
					GHDUserViewController *self = t.last;
					[self.userAccount setValuesForKeysWithDictionary:t.first];
					return [RACUnit defaultUnit];
				}];
}

- (RACSubscribable *)fetchRepos {	
	return [[[self.client 
				fetchUserRepos] 
				injectObjectWeakly:self] 
				select:^(RACTuple *t) {
					NSLog(@"repos: %@", t.first);
					return [RACUnit defaultUnit];
				}];
}

- (RACSubscribable *)fetchOrgs {	
	return [[[self.client 
				fetchUserRepos] 
				injectObjectWeakly:self]
				select:^(RACTuple *t) {
					NSLog(@"orgs: %@", t.first);
					return [RACUnit defaultUnit];
				}];
}

- (RACSubscribable *)loadImageAtURL:(NSURL *)URL {
	// This -defer, -publish, -autoconnect dance might seem a little odd, so 
	// let's talk through it.
	//
	// We're using -defer because -startWithScheduler:block: returns us a hot 
	// subscribable but we really want a cold one. Why do we want a cold one? 
	// It lets us defer the actual work of loading the image until someone 
	// actually cares enough about it to subscribe. But even more than that, 
	// cold subscribables let us use operations like -retry: or -repeat:.
	//
	// But the downside to cold subscribables is that subsequent subscribers
	// will cause the subscribable to fire again, which we don't really want.
	// So we use -publish to share the subscriptions to the underlying subscribable.
	// -autoconnect means the connectable subscribable from -publish will connect
	// automatically when it receives its first subscriber.
	RACSubscribable *loadImage = [RACSubscribable defer:^{
		return [RACSubscribable startWithScheduler:[RACScheduler immediateScheduler] block:^id(BOOL *success, NSError **error) {
			NSImage *image = [[NSImage alloc] initWithContentsOfURL:URL];
			if(image == nil) {
				*success = NO;
				return nil;
			}
			
			return image;
		}];
	}];
	
	return [[[[loadImage 
				retry:1] 
				catchTo:[RACSubscribable return:[NSImage imageNamed:NSImageNameUser]]] 
				publish] 
				autoconnect];
}

@end
