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

- (GHJSONRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)request {
	return (GHJSONRequestOperation *) [super HTTPRequestOperationWithRequest:request success:^(AFHTTPRequestOperation *operation, id responseObject) {
		GHJSONRequestOperation *op = (GHJSONRequestOperation *) operation;
		op.RACAsyncCallback(responseObject, YES, nil);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		GHJSONRequestOperation *op = (GHJSONRequestOperation *) operation;
		op.RACAsyncCallback(nil, NO, error);
	}];
}

- (GHJSONRequestOperation *)operationWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
	NSURLRequest *request = [self requestWithMethod:method path:path parameters:parameters];
	return [self HTTPRequestOperationWithRequest:request];
}

@end
