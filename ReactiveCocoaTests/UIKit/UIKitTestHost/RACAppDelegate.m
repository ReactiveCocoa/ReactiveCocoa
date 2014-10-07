//
//  RACAppDelegate.m
//  ReactiveCocoa-iOS-UIKitTestHost
//
//  Created by Andrew Mackenzie-Ross on 27/06/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAppDelegate.h"

@implementation RACAppDelegate

+ (instancetype)delegate {
	return (id)UIApplication.sharedApplication.delegate;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    [self.window makeKeyAndVisible];

    return YES;
}

@end
