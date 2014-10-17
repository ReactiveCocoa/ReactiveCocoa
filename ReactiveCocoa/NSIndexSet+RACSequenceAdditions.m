//
//  NSIndexSet+RACSequenceAdditions.m
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/17/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSIndexSet+RACSequenceAdditions.h"
#import "RACIndexSetSequence.h"

@implementation NSIndexSet (RACSequenceAdditions)

- (RACSequence *)rac_sequence {
	return [RACIndexSetSequence sequenceWithIndexSet:self];
}

@end
