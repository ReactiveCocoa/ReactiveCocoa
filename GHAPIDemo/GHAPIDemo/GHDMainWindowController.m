//
//  GHDMainWindowController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDMainWindowController.h"

@interface GHDMainWindowController ()

@end


@implementation GHDMainWindowController

- (id)init {
	self = [super initWithWindowNibName:NSStringFromClass([self class]) owner:self];
	if(self == nil) return nil;
	
	return self;
}


#pragma mark NSWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
}

@end
