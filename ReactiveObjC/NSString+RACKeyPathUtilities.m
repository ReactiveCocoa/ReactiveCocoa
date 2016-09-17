//
//  NSString+RACKeyPathUtilities.m
//  ReactiveObjC
//
//  Created by Uri Baghin on 05/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSString+RACKeyPathUtilities.h"

@implementation NSString (RACKeyPathUtilities)

- (NSArray *)rac_keyPathComponents {
	if (self.length == 0) {
		return nil;
	}
	return [self componentsSeparatedByString:@"."];
}

- (NSString *)rac_keyPathByDeletingLastKeyPathComponent {
	NSUInteger lastDotIndex = [self rangeOfString:@"." options:NSBackwardsSearch].location;
	if (lastDotIndex == NSNotFound) {
		return nil;
	}
	return [self substringToIndex:lastDotIndex];
}

- (NSString *)rac_keyPathByDeletingFirstKeyPathComponent {
	NSUInteger firstDotIndex = [self rangeOfString:@"."].location;
	if (firstDotIndex == NSNotFound) {
		return nil;
	}
	return [self substringFromIndex:firstDotIndex + 1];
}

@end
