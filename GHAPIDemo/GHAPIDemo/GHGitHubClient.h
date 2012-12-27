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
- (RACSignal *)login;
- (RACSignal *)fetchUserInfo;

- (RACSignal *)fetchUserRepos;
- (RACSignal *)createRepoWithName:(NSString *)name description:(NSString *)description private:(BOOL)isPrivate;

// Orgs
- (RACSignal *)fetchUserOrgs;
- (RACSignal *)fetchOrgInfo:(GHGitHubOrg *)org;

- (RACSignal *)fetchReposForOrg:(GHGitHubOrg *)org;
- (RACSignal *)createRepoWithName:(NSString *)name org:(GHGitHubOrg *)org team:(GHGitHubTeam *)team description:(NSString *)description private:(BOOL)isPrivate;

// Public Keys
- (RACSignal *)fetchPublicKeys;
- (RACSignal *)postPublicKey:(NSString *)key title:(NSString *)title;

@end
