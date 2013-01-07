//
//  NSEnumerator+RACSequenceAdditions.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 07/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSEnumerator+RACSequenceAdditions.h"
#import "RACSequence.h"
#import "EXTScope.h"

@implementation NSEnumerator (RACSequenceAdditions)

- (RACSequence *)rac_sequence {
	return [RACSequence sequenceWithHeadBlock:^id{
		return self.nextObject;
	} tailBlock:^RACSequence *{
		return self.rac_sequence;
	}];
}

@end
