//
//  GHDMainWindowController.h
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AFNetworking.h"


@interface GHDMainWindowController : NSWindowController

@property (nonatomic, readonly) AFHTTPClient *gitHubClient;

@end
