//
//  GHGitHubClient.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AFNetworking.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@class GHJSONRequestOperation;
@class GHUserAccount;


@interface GHGitHubClient : AFHTTPClient

@property (nonatomic, readonly, strong) GHUserAccount *userAccount;

+ (GHGitHubClient *)clientForUserAccount:(GHUserAccount *)userAccount;

- (RACSequence *)login;
- (RACSequence *)fetchUserInfo;
- (RACSequence *)fetchUserRepos;
- (RACSequence *)fetchUserOrgs;

@end
