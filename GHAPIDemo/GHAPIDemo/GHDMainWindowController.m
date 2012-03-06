//
//  GHDMainWindowController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDMainWindowController.h"
#import "GHDLoginViewController.h"

@interface GHDMainWindowController ()
@property (nonatomic, strong) GHDLoginViewController *loginViewController;
@end


@implementation GHDMainWindowController

- (id)init {
	self = [super initWithWindowNibName:NSStringFromClass([self class]) owner:self];
	if(self == nil) return nil;
	
	self.loginViewController = [[GHDLoginViewController alloc] init];
	
	return self;
}


#pragma mark NSWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
	
	self.window.contentView = self.loginViewController.view;
}


#pragma mark API

@synthesize loginViewController;

@end
