//
//  GHGitHubClient.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AFNetworking.h"

@class GHJSONRequestOperation;
@class GHUserAccount;


@interface GHGitHubClient : AFHTTPClient

@property (nonatomic, readonly, strong) GHUserAccount *userAccount;

+ (GHGitHubClient *)clientForUserAccount:(GHUserAccount *)userAccount;

- (GHJSONRequestOperation *)operationWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters;

- (GHJSONRequestOperation *)operationToLogin;
- (GHJSONRequestOperation *)operationToGetCurrentUserInfo;
- (GHJSONRequestOperation *)operationToGetCurrentUsersRepos;
- (GHJSONRequestOperation *)operationToGetCurrentUsersOrgs;

@end
