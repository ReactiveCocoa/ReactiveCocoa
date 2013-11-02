//
//  NSArray+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSArray+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACArraySequence.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSArray (RACSupport)

- (RACSignal *)rac_signal {
	NSArray *collection = [self copy];

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

@implementation NSArray (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	return [RACArraySequence sequenceWithArray:self offset:0];
}

@end

#pragma clang diagnostic pop
