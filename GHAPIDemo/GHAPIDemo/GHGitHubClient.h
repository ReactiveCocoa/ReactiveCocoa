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
- (id<RACSignal>)login;
- (id<RACSignal>)fetchUserInfo;

- (id<RACSignal>)fetchUserRepos;
- (id<RACSignal>)createRepoWithName:(NSString *)name description:(NSString *)description private:(BOOL)isPrivate;

// Orgs
- (id<RACSignal>)fetchUserOrgs;
- (id<RACSignal>)fetchOrgInfo:(GHGitHubOrg *)org;

- (id<RACSignal>)fetchReposForOrg:(GHGitHubOrg *)org;
- (id<RACSignal>)createRepoWithName:(NSString *)name org:(GHGitHubOrg *)org team:(GHGitHubTeam *)team description:(NSString *)description private:(BOOL)isPrivate;

// Public Keys
- (id<RACSignal>)fetchPublicKeys;
- (id<RACSignal>)postPublicKey:(NSString *)key title:(NSString *)title;

@end
