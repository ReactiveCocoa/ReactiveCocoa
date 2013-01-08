//
//  NSEnumerator+RACSignalAdditions.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSEnumerator+RACSignalAdditions.h"
#import "RACScheduler.h"
#import "RACSignal.h"
#import "RACSubscriber.h"
#import <libkern/OSAtomic.h>

@implementation NSEnumerator (RACSignalAdditions)

- (RACSignal *)rac_signal {
	return [self rac_signalWithScheduler:[RACScheduler scheduler]];
}

- (RACSignal *)rac_signalWithScheduler:(RACScheduler *)scheduler {
	__block volatile uint32_t notFirstSubscriber = 0;
	return [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		int32_t oldNotFirstSubscriber = OSAtomicOr32OrigBarrier(1, &notFirstSubscriber);
		if (oldNotFirstSubscriber != 0) {
			[subscriber sendCompleted];
			return nil;
		}
		return [scheduler scheduleRecursiveBlock:^(void (^reschedule)(void)) {
			id object = [self nextObject];
			if (object == nil) {
				[subscriber sendCompleted];
				return;
			}
			[subscriber sendNext:object];
			reschedule();
		}];
	}];
}

@end
