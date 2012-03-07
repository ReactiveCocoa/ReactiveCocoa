//
//  GHGitHubClient.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHGitHubClient.h"
#import "GHJSONRequestOperation.h"


@implementation GHGitHubClient


#pragma mark API

+ (GHGitHubClient *)sharedClient {
	static dispatch_once_t onceToken;
	static GHGitHubClient *client = nil;
	dispatch_once(&onceToken, ^{
		client = [[self alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.github.com"]];
	});
	
	return client;
}

- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
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

@end
