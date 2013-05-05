//
//  NSString+RACKeyPathUtilities.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 05/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSString+RACKeyPathUtilities.h"

@implementation NSString (RACKeyPathUtilities)

- (NSArray *)keyPathComponents {
	if (self.length == 0) {
		return nil;
	}
	return [self componentsSeparatedByString:@"."];
}

- (NSString *)keyPathByDeletingLastKeyPathComponent {
	NSUInteger lastDotIndex = [self rangeOfString:@"." options:NSBackwardsSearch].location;
	if (lastDotIndex == NSNotFound) {
		return nil;
	}
	return [self substringToIndex:lastDotIndex];
}

@end
