//
//  GHGitHubUser.m
//
//  Created by Josh Abernathy on 3/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHGitHubUser.h"

static NSString * const GHGitHubUserDefaultAPIEndpoint = @"https://api.github.com";

@interface GHGitHubUser ()
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSURL *APIEndpoint;
@property (nonatomic, copy) NSString *realName;
@end


@implementation GHGitHubUser

- (void)setValuesForKeysWithDictionary:(NSDictionary *)keyedValues {
	self.realName = [keyedValues objectForKey:@"name"];
}


#pragma mark API

@synthesize username;
@synthesize password;
@synthesize APIEndpoint;
@synthesize realName;
@synthesize objectID;

+ (GHGitHubUser *)userWithUsername:(NSString *)username password:(NSString *)password {
	return [self userWithUsername:username password:password APIEndpoint:[NSURL URLWithString:GHGitHubUserDefaultAPIEndpoint]];
}

+ (GHGitHubUser *)userWithUsername:(NSString *)username password:(NSString *)password APIEndpoint:(NSURL *)URL {
	GHGitHubUser *account = [[self alloc] init];
	account.username = username;
	account.password = password;
	account.APIEndpoint = URL;
	return account;
}

@end
