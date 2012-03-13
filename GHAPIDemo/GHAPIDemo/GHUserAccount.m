//
//  GHUserAccount.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHUserAccount.h"

static NSString * const GHUserAccountDefaultAPIEndpoint = @"https://api.github.com";

@interface GHUserAccount ()
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSURL *APIEndpoint;
@end


@implementation GHUserAccount


#pragma mark API

@synthesize username;
@synthesize password;
@synthesize APIEndpoint;
@synthesize realName;

+ (GHUserAccount *)userAccountWithUsername:(NSString *)username password:(NSString *)password {
	return [self userAccountWithUsername:username password:password APIEndpoint:[NSURL URLWithString:GHUserAccountDefaultAPIEndpoint]];
}

+ (GHUserAccount *)userAccountWithUsername:(NSString *)username password:(NSString *)password APIEndpoint:(NSURL *)URL {
	GHUserAccount *account = [[self alloc] init];
	account.username = username;
	account.password = password;
	account.APIEndpoint = URL;
	return account;
}

@end
