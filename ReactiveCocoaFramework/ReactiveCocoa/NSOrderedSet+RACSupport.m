//
//  NSOrderedSet+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSOrderedSet+RACSupport.h"
#import "NSArray+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSOrderedSet (RACSupport)

- (RACSignal *)rac_signal {
	NSOrderedSet *collection = [self copy];

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		for (id obj in collection) {
			[subscriber sendNext:obj];

			if (subscriber.disposable.disposed) return;
		}

		[subscriber sendCompleted];
	}] setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSOrderedSet (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	// TODO: First class support for ordered set sequences.
	return self.array.rac_sequence;
}

@end

#pragma clang diagnostic pop
