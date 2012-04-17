//
//  GHDAppDelegate.m
//  RACiOSDemo
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDAppDelegate.h"
#import "GHDMainViewController.h"

@interface GHDAppDelegate ()
@property (nonatomic, strong) UINavigationController *navigationController;
@end


@implementation GHDAppDelegate


#pragma mark UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	GHDMainViewController *mainViewController = [[GHDMainViewController alloc] initWithNibName:nil bundle:nil];
	self.navigationController = [[UINavigationController alloc] initWithRootViewController:mainViewController];
	
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
	self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
    return YES;
}


#pragma mark API

@synthesize window;
@synthesize navigationController;

@end
