//
//  NSFileHandle+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSFileHandle+RACSupport.h"
#import "RACPromise.h"
#import "RACScheduler.h"
#import "RACSubscriber.h"

@implementation NSFileHandle (RACSupport)

- (RACPromise *)rac_availableData {
	return [RACPromise promiseWithScheduler:[RACScheduler scheduler] block:^(id<RACSubscriber> subscriber) {
		self.readabilityHandler = ^(NSFileHandle *handle) {
			NSData *data = [handle availableData];
			if (data.length > 0) {
				[subscriber sendNext:data];
			} else {
				[subscriber sendCompleted];
				handle.readabilityHandler = nil;
			}
		};
	}];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSFileHandle (RACSupportDeprecated)

- (RACSignal *)rac_readInBackground {
	return [self.rac_availableData start];
}

@end

#pragma clang diagnostic pop
