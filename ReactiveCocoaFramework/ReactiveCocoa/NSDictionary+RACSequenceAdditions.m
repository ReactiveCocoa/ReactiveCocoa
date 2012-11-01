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

- (RACSequence *)rac_sequence {
	return self.allKeys.rac_sequence;
}

- (RACSequence *)rac_valueSequence {
	return self.allValues.rac_sequence;
}

@end
