//
//  NSOrderedSet+RACSequenceAdditions.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSOrderedSet+RACSequenceAdditions.h"
#import "NSArray+RACSequenceAdditions.h"

@implementation NSOrderedSet (RACSequenceAdditions)

- (RACSequence *)mtl_sequence {
	// TODO: First class support for ordered set sequences.
	return self.array.mtl_sequence;
}

@end
