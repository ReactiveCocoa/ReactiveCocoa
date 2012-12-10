//
//  GHDUserViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDUserViewController.h"
#import "EXTScope.h"
#import "GHDUserView.h"
#import "GHGitHubClient.h"
#import "GHGitHubUser.h"
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
	
	[self.view.usernameTextField rac_bind:NSValueBinding toObject:self withKeyPath:@keypath(self.userAccount.username)];
	[self.view.realNameTextField rac_bind:NSValueBinding toObject:self withKeyPath:@keypath(self.userAccount.realName)];
	[self.view.spinner rac_bind:NSHiddenBinding toObject:self withNegatedKeyPath:@keypath(self.loading)];
	[self.view.valuesContainerView rac_bind:NSHiddenBinding toObject:self withKeyPath:@keypath(self.loading)];
	[self.view.avatarImageView rac_bind:NSValueBinding toObject:self withKeyPath:@keypath(self.avatar)];
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
	
	@unsafeify(self);

	// We're using -merge: so that -fetchUser, -fetchRepos, and -fetchOrgs are 
	// all executed independently. We're then told when they've all completed.
	// -finally: lets us share logic regardless of whether we get an error or 
	// complete successfully.
	[[[RACSignal 
		merge:[NSArray arrayWithObjects:[self fetchUser], [self fetchRepos], [self fetchOrgs], nil]] 
		finally:^{
			@strongify(self);
			self.loading = NO;
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
	id<RACSignal> loadedAvatar = [[[[RACAble(self.userAccount.avatarURL) 
		filter:^ BOOL (id x) {
			return x != nil;
		}] 
		deliverOn:[RACScheduler scheduler]]
		flattenMap:^(NSURL *URL) {
			@strongify(self);

			return [self loadImageAtURL:URL];
		}] 
		deliverOn:RACScheduler.mainThreadScheduler];
	
	// -merge: takes the latest value from the Signals. In this case, 
	// we're using -[RACSignal return:] to make a Signal that 
	// immediately sends the default image, and will use the loaded avatar when
	// it loads.
	[[RACSignal 
		merge:[NSArray arrayWithObjects:[RACSignal return:[NSImage imageNamed:NSImageNameUser]], loadedAvatar, nil]] 
		toProperty:@keypath(self.avatar) onObject:self];
	
	return self;
}

- (id<RACSignal>)fetchUser {	
	@unsafeify(self);
	return [[self.client 
				fetchUserInfo] 
				map:^(NSDictionary *userDict) {
					@strongify(self);

					[self.userAccount setValuesForKeysWithDictionary:userDict];
					return [RACUnit defaultUnit];
				}];
}

- (id<RACSignal>)fetchRepos {	
	return [[self.client 
				fetchUserRepos] 
				map:^(NSArray *repos) {
					NSLog(@"repos: %@", repos);
					return [RACUnit defaultUnit];
				}];
}

- (id<RACSignal>)fetchOrgs {	
	return [[self.client 
				fetchUserOrgs] 
				map:^(NSArray *orgs) {
					NSLog(@"orgs: %@", orgs);
					return [RACUnit defaultUnit];
				}];
}

- (id<RACSignal>)loadImageAtURL:(NSURL *)URL {
	// This -defer, -publish, -autoconnect dance might seem a little odd, so 
	// let's talk through it.
	//
	// We're using -defer because -startWithScheduler:block: returns us a hot 
	// Signal but we really want a cold one. Why do we want a cold one? 
	// It lets us defer the actual work of loading the image until someone 
	// actually cares enough about it to subscribe. But even more than that, 
	// cold Signals let us use operations like -retry: or -repeat:.
	//
	// But the downside to cold Signals is that subsequent subscribers
	// will cause the Signal to fire again, which we don't really want.
	// So we use -publish to share the subscriptions to the underlying Signal.
	// -autoconnect means the connectable Signal from -publish will connect
	// automatically when it receives its first subscriber.
	id<RACSignal> loadImage = [RACSignal defer:^{
		return [RACSignal startWithScheduler:[RACScheduler immediateScheduler] block:^id(BOOL *success, NSError **error) {
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
				catchTo:[RACSignal return:[NSImage imageNamed:NSImageNameUser]]] 
				publish] 
				autoconnect];
}

@end
