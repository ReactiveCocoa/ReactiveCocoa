//
//  NSOrderedSet+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSOrderedSet+RACSupport.h"
#import "NSArray+RACSupport.h"

@implementation NSOrderedSet (RACSupport)

- (RACSequence *)rac_sequence {
	// TODO: First class support for ordered set sequences.
	return self.array.rac_sequence;
}

@end
