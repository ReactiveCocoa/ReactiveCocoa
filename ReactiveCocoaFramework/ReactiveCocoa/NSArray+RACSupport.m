//
//  NSArray+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSArray+RACSupport.h"
#import "RACArraySequence.h"

@implementation NSArray (RACSupport)

- (RACSequence *)rac_sequence {
	return [RACArraySequence sequenceWithArray:self offset:0];
}

@end
