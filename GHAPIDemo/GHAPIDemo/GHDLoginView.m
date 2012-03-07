//
//  GHDLoginView.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDLoginView.h"


@implementation GHDLoginView


#pragma mark API

@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize loginButton;
@synthesize successTextField;
@synthesize couldNotLoginTextField;
@synthesize loggingInSpinner;

+ (id)view {
	NSNib *nib = [[NSNib alloc] initWithNibNamed:NSStringFromClass(self) bundle:nil];
	NSArray *topLevelObjects = nil;
	BOOL success = [nib instantiateNibWithOwner:self topLevelObjects:&topLevelObjects];
	if(!success) return nil;
		
	NSView *view = nil;
	for(id topLevelObject in topLevelObjects) {
		if([topLevelObject isKindOfClass:self]) {
			view = topLevelObject;
			break;
		}
	}
	
	return view;
}

@end
