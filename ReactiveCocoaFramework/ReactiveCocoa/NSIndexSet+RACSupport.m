//
//  NSIndexSet+RACSupport.m
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/17/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSIndexSet+RACSupport.h"

#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACIndexSetSequence.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSIndexSet (RACSupport)

- (RACSignal *)rac_signal {
	NSIndexSet *indexes = [self copy];

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			[indexes enumerateIndexesUsingBlock:^(NSUInteger index, BOOL *stop) {
				[subscriber sendNext:@(index)];
				*stop = subscriber.disposable.disposed;
			}];

			[subscriber sendCompleted];
		}]
		setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

@implementation NSIndexSet (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	return [RACIndexSetSequence sequenceWithIndexSet:self];
}

@end

#pragma clang diagnostic pop
