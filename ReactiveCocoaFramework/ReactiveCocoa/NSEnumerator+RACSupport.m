//
//  NSEnumerator+RACSupport.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 07/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSEnumerator+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACPromise.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"

@implementation NSEnumerator (RACSupport)

- (RACPromise *)rac_promise {
	return [[[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			for (id obj in self) {
				[subscriber sendNext:obj];

				if (subscriber.disposable.disposed) return;
			}

			[subscriber sendCompleted];
		}]
		setNameWithFormat:@"%@ -rac_promise", self.rac_description]
		promiseOnScheduler:RACScheduler.immediateScheduler];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSEnumerator (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	return [RACSequence sequenceWithHeadBlock:^{
		return [self nextObject];
	} tailBlock:^{
		return self.rac_sequence;
	}];
}

@end

#pragma clang diagnostic pop
