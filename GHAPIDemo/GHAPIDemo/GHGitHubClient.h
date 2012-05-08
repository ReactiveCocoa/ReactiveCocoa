//
//  GHGitHubClient.h
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "AFNetworking.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@class GHGitHubUser;
@class GHGitHubOrg;
@class GHGitHubTeam;


@interface GHGitHubClient : AFHTTPClient

@property (nonatomic, readonly, strong) GHGitHubUser *user;

+ (GHGitHubClient *)clientForUser:(GHGitHubUser *)user;

// User
- (RACSubscribable *)login;
- (RACSubscribable *)fetchUserInfo;

- (RACSubscribable *)fetchUserRepos;
- (RACSubscribable *)createRepoWithName:(NSString *)name description:(NSString *)description private:(BOOL)isPrivate;

// Orgs
- (RACSubscribable *)fetchUserOrgs;
- (RACSubscribable *)fetchOrgInfo:(GHGitHubOrg *)org;

- (RACSubscribable *)fetchReposForOrg:(GHGitHubOrg *)org;
- (RACSubscribable *)createRepoWithName:(NSString *)name org:(GHGitHubOrg *)org team:(GHGitHubTeam *)team description:(NSString *)description private:(BOOL)isPrivate;

// Public Keys
- (RACSubscribable *)fetchPublicKeys;
- (RACSubscribable *)postPublicKey:(NSString *)key title:(NSString *)title;

@end
