//
//  GHDAppDelegate.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDAppDelegate.h"

#import "GHDMainWindowController.h"

@interface GHDAppDelegate ()
@property (nonatomic, strong) GHDMainWindowController *mainWindowController;
@end


@implementation GHDAppDelegate


#pragma mark NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	self.mainWindowController = [[GHDMainWindowController alloc] init];
	[self.mainWindowController.window makeKeyAndOrderFront:nil];
}


#pragma mark API

@synthesize mainWindowController;

@end
