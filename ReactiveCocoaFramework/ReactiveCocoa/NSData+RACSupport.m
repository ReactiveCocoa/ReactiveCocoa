//
//  NSData+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSData+RACSupport.h"
#import "RACPromise.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSData (RACSupport)

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);

	return [[[RACPromise
		promiseWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
			NSError *error = nil;
			NSData *data = [[NSData alloc] initWithContentsOfURL:URL options:options error:&error];
			if (data == nil) {
				[subscriber sendError:error];
			} else {
				[subscriber sendNext:data];
				[subscriber sendCompleted];
			}
		}]
		start]
		setNameWithFormat:@"+rac_readContentsOfURL: %@ options: %lu scheduler: %@", URL, (unsigned long)options, scheduler];
}

@end
