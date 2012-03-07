//
//  GHUserAccount.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface GHUserAccount : NSObject

@property (nonatomic, readonly, copy) NSString *username;
@property (nonatomic, readonly, copy) NSString *password;
@property (nonatomic, readonly, copy) NSURL *APIEndpoint;

+ (GHUserAccount *)userAccountWithUsername:(NSString *)username password:(NSString *)password;
+ (GHUserAccount *)userAccountWithUsername:(NSString *)username password:(NSString *)password APIEndpoint:(NSURL *)URL;

@end
