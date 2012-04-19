//
//  NSView+GHDExtensions.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSView+GHDExtensions.h"


@implementation NSView (GHDExtensions)

+ (id)ghd_viewFromNib {
	return [self ghd_viewFromNibNamed:NSStringFromClass(self)];
}

+ (id)ghd_viewFromNibNamed:(NSString *)nibName {
	NSNib *nib = [[NSNib alloc] initWithNibNamed:nibName bundle:nil];
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
