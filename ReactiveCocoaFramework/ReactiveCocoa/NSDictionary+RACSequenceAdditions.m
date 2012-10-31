//
//  NSDictionary+RACSequenceAdditions.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSDictionary+RACSequenceAdditions.h"
#import "NSArray+RACSequenceAdditions.h"

@implementation NSDictionary (RACSequenceAdditions)

// TODO: Sequence of key/value pairs.

- (RACSequence *)mtl_sequence {
	return self.allKeys.mtl_sequence;
}

- (RACSequence *)mtl_valueSequence {
	return self.allValues.mtl_sequence;
}

@end
