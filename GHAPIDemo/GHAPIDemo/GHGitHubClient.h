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
- (RACAsyncSubject *)login;
- (RACAsyncSubject *)fetchUserInfo;

- (RACAsyncSubject *)fetchUserRepos;
- (RACAsyncSubject *)createRepoWithName:(NSString *)name description:(NSString *)description private:(BOOL)isPrivate;

// Orgs
- (RACAsyncSubject *)fetchUserOrgs;
- (RACAsyncSubject *)fetchOrgInfo:(GHGitHubOrg *)org;

- (RACAsyncSubject *)fetchReposForOrg:(GHGitHubOrg *)org;
- (RACAsyncSubject *)createRepoWithName:(NSString *)name org:(GHGitHubOrg *)org team:(GHGitHubTeam *)team description:(NSString *)description private:(BOOL)isPrivate;

// Public Keys
- (RACAsyncSubject *)fetchPublicKeys;
- (RACAsyncSubject *)postPublicKey:(NSString *)key title:(NSString *)title;

@end
