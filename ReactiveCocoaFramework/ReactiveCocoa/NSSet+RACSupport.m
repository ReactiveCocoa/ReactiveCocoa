//
//  NSSet+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSSet+RACSupport.h"
#import "NSArray+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSSet (RACSupport)

- (RACSignal *)rac_signal {
	NSOrderedSet *collection = [self copy];

	return [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		for (id obj in collection) {
			[subscriber sendNext:obj];
		}

		[subscriber sendCompleted];
		return nil;
	}] setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSSet (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	// TODO: First class support for set sequences.
	return self.allObjects.rac_sequence;
}

@end

#pragma clang diagnostic pop
