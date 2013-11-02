//
//  NSEnumerator+RACSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 07/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSEnumerator+RACSupport.h"
#import "RACSequence.h"

@implementation NSEnumerator (RACSupport)

- (RACSequence *)rac_sequence {
	return [RACSequence sequenceWithHeadBlock:^{
		return [self nextObject];
	} tailBlock:^{
		return self.rac_sequence;
	}];
}

@end
