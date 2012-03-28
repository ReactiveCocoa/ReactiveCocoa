//
//  GHGitHubClient.m
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHGitHubClient.h"
#import "GHGitHubUser.h"
#import "GHGitHubOrg.h"
#import "GHGitHubTeam.h"


@interface GHGitHubClient ()
@property (nonatomic, strong) GHGitHubUser *user;
@end


@implementation GHGitHubClient


#pragma mark API

@synthesize user;

+ (GHGitHubClient *)clientForUser:(GHGitHubUser *)user {
	GHGitHubClient *client = [[self alloc] initWithBaseURL:user.APIEndpoint];
	client.user = user;
	return client;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if(self == nil) return nil;
	
	[self registerHTTPOperationClass:[AFJSONRequestOperation class]];
	[self setDefaultHeader:@"Accept" value:@"application/json"];

    return self;
}

- (RACAsyncSubject *)login {
	return [self enqueueRequestWithMethod:@"GET" path:@"" parameters:nil];
}

- (RACAsyncSubject *)fetchUserInfo {
	return [self enqueueRequestWithMethod:@"GET" path:@"user" parameters:nil];
}

- (RACAsyncSubject *)fetchUserRepos {
	return [self enqueueRequestWithMethod:@"GET" path:@"user/repos" parameters:nil];
}

- (RACAsyncSubject *)fetchUserOrgs {
	return [self enqueueRequestWithMethod:@"GET" path:@"user/orgs" parameters:nil];
}

- (RACAsyncSubject *)fetchOrgInfo:(GHGitHubOrg *)org {
	return [self enqueueRequestWithMethod:@"GET" path:[NSString stringWithFormat:@"orgs/%@", org.username] parameters:nil];
}

- (RACAsyncSubject *)fetchReposForOrg:(GHGitHubOrg *)org {
	return [self enqueueRequestWithMethod:@"GET" path:[NSString stringWithFormat:@"orgs/%@/repos", org.username] parameters:nil];
}

- (RACAsyncSubject *)fetchPublicKeys {
	return [self enqueueRequestWithMethod:@"GET" path:@"user/keys" parameters:nil];
}

- (RACAsyncSubject *)createRepoWithName:(NSString *)name description:(NSString *)description private:(BOOL)isPrivate {
	return [self createRepoWithName:name org:nil team:nil description:description private:isPrivate];
}

- (RACAsyncSubject *)createRepoWithName:(NSString *)name org:(GHGitHubOrg *)org team:(GHGitHubTeam *)team description:(NSString *)description private:(BOOL)isPrivate {
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	[options setObject:name forKey:@"name"];
	[options setObject:description forKey:@"description"];
	[options setObject:isPrivate ? @"true" : @"false" forKey:@"private"];
	if(team != nil) [options setObject:team.objectID forKey:@"team_id"];
	
	NSString *path = org == nil ? @"user/repos" : [NSString stringWithFormat:@"orgs/%@/repos", org.username];
	return [self enqueueRequestWithMethod:@"POST" path:path parameters:options];
}

- (RACAsyncSubject *)postPublicKey:(NSString *)key title:(NSString *)title {
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	[options setObject:key forKey:@"key"];
	[options setObject:title forKey:@"title"];
	return [self enqueueRequestWithMethod:@"POST" path:@"user/keys" parameters:options];
}

- (RACAsyncSubject *)enqueueRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	RACAsyncSubject *subject = [RACAsyncSubject subject];
	NSURLRequest *request = [self requestWithMethod:method path:path parameters:parameters];
	AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		[subject sendNext:[RACMaybe maybeWithObject:responseObject]];
		[subject sendCompleted];
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		[subject sendError:error];
	}];
	
    [self enqueueHTTPRequestOperation:operation];
	
	return subject;
}

- (void)setUser:(GHGitHubUser *)u {
	if(user == u) return;
	
	user = u;
	
	[self setAuthorizationHeaderWithUsername:self.user.username password:self.user.password];
}

@end
