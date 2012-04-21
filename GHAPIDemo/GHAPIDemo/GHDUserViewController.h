//
//  GHDUserViewController.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GHGitHubUser;


@interface GHDUserViewController : NSViewController

- (id)initWithUserAccount:(GHGitHubUser *)user;

@end
