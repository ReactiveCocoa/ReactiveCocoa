//
//  NSData+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSData+RACSupport.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"

@implementation NSData (RACSupport)

+ (RACSignal *)rac_contentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options {
	NSCParameterAssert(URL != nil);

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			NSError *error = nil;
			NSData *data = [[NSData alloc] initWithContentsOfURL:URL options:options error:&error];
			if (data == nil) {
				[subscriber sendError:error];
			} else {
				[subscriber sendNext:data];
				[subscriber sendCompleted];
			}
		}]
		setNameWithFormat:@"+rac_contentsOfURL: %@ options: %lu", URL, (unsigned long)options];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSData (RACSupportDeprecated)

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);

	RACReplaySubject *subject = [RACReplaySubject subject];

	[[[self
		rac_contentsOfURL:URL options:options]
		subscribeOn:scheduler]
		subscribe:subject];

	return [subject setNameWithFormat:@"+rac_readContentsOfURL: %@ options: %lu scheduler: %@", URL, (unsigned long)options, scheduler];
}

@end

#pragma clang diagnostic pop
