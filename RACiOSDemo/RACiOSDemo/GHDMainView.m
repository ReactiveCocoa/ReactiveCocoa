//
//  GHDMainView.m
//  RACiOSDemo
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GHDMainView.h"


@implementation GHDMainView


#pragma mark API

@synthesize textField;
@synthesize label;
@synthesize textView;
@synthesize label2;

+ (id)viewFromNib {
	NSArray *topLevelObjects = [[UINib nibWithNibName:NSStringFromClass(self) bundle:nil] instantiateWithOwner:nil options:nil];
	for(id object in topLevelObjects) {
		if([object isKindOfClass:self]) {
			return object;
		}
	}
	
	NSAssert(NO, @"We didn't find a top-level object of class %@", NSStringFromClass(self));
	
	return nil;
}

@end
