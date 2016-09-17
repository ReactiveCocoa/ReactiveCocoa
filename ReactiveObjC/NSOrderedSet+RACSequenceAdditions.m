//
//  NSOrderedSet+RACSequenceAdditions.m
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSOrderedSet+RACSequenceAdditions.h"
#import "NSArray+RACSequenceAdditions.h"

@implementation NSOrderedSet (RACSequenceAdditions)

- (RACSequence *)rac_sequence {
	// TODO: First class support for ordered set sequences.
	return self.array.rac_sequence;
}

@end
