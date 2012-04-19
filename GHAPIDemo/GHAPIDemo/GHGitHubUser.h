//
//  GHGitHubUser.h
//
//  Created by Josh Abernathy on 3/7/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GHGitHubObject.h"


@interface GHGitHubUser : GHGitHubObject

@property (nonatomic, readonly, copy) NSString *username;
@property (nonatomic, readonly, copy) NSString *password;
@property (nonatomic, readonly, copy) NSURL *APIEndpoint;
@property (nonatomic, readonly, copy) NSString *realName;
@property (nonatomic, readonly, copy) NSURL *avatarURL;

+ (GHGitHubUser *)userWithUsername:(NSString *)username password:(NSString *)password;
+ (GHGitHubUser *)userWithUsername:(NSString *)username password:(NSString *)password APIEndpoint:(NSURL *)URL;

@end
