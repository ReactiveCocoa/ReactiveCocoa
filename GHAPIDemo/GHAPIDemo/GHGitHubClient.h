//
//  GHGitHubClient.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AFNetworking.h"

@class GHJSONRequestOperation;


@interface GHGitHubClient : AFHTTPClient

+ (GHGitHubClient *)sharedClient;

- (GHJSONRequestOperation *)HTTPRequestOperationWithRequest:(NSURLRequest *)request;

@end
