//
//  NSDictionary+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSDictionary+RACSupport.h"
#import "NSArray+RACSupport.h"
#import "RACSequence.h"
#import "RACTuple.h"

@implementation NSDictionary (RACSupport)

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSDictionary (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	NSDictionary *immutableDict = [self copy];

	// TODO: First class support for dictionary sequences.
	return [immutableDict.allKeys.rac_sequence map:^(id key) {
		id value = immutableDict[key];
		return [RACTuple tupleWithObjects:key, value, nil];
	}];
}

- (RACSequence *)rac_keySequence {
	return self.allKeys.rac_sequence;
}

- (RACSequence *)rac_valueSequence {
	return self.allValues.rac_sequence;
}

@end

#pragma clang diagnostic pop
