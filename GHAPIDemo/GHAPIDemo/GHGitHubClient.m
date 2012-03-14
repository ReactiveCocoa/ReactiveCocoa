//
//  GHGitHubClient.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHGitHubClient.h"
#import "GHJSONRequestOperation.h"
#import "GHUserAccount.h"
#import <ReactiveCocoa/RACSequence+Private.h>

@interface GHGitHubClient ()
@property (nonatomic, strong) GHUserAccount *userAccount;
@end


@implementation GHGitHubClient


#pragma mark API

@synthesize userAccount;

+ (GHGitHubClient *)clientForUserAccount:(GHUserAccount *)userAccount {
	GHGitHubClient *client = [[self alloc] initWithBaseURL:userAccount.APIEndpoint];
	[client setAuthorizationHeaderWithUsername:userAccount.username password:userAccount.password];
	client.userAccount = userAccount;
	return client;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if(self == nil) return nil;
    
    [self registerHTTPOperationClass:[GHJSONRequestOperation class]];
    
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

- (RACAsyncSubject *)enqueueRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	RACAsyncSubject *subject = [RACAsyncSubject subject];
	NSURLRequest *request = [self requestWithMethod:method path:path parameters:parameters];
	AFHTTPRequestOperation *operation = [self HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		[subject sendNext:[RACMaybe maybeWithObject:responseObject]];
		[subject sendCompletedToAllObservers];
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		[subject sendNext:[RACMaybe maybeWithError:error]];
		[subject sendCompletedToAllObservers];
	}];
	
    [self enqueueHTTPRequestOperation:operation];
	
	return subject;
}

@end
