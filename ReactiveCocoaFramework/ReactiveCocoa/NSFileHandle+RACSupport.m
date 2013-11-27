//
//  NSFileHandle+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSFileHandle+RACSupport.h"
#import "NSNotificationCenter+RACSupport.h"
#import "RACPromise.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"

@implementation NSFileHandle (RACSupport)

- (RACSignal *)rac_readInBackground {
	return [[[[[[[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			[[NSNotificationCenter.defaultCenter
				rac_addObserverForName:NSFileHandleReadCompletionNotification object:self]
				subscribe:subscriber];

			[self readInBackgroundAndNotify];
		}]
		map:^(NSNotification *note) {
			return note.userInfo[NSFileHandleNotificationDataItem];
		}]
		takeWhile:^ BOOL (NSData *data) {
			return data.length > 0;
		}]
		flattenMap:^(NSData *data) {
			// Deliver the data to the subscriber first, then read more.
			return [[RACSignal
				return:data]
				doCompleted:^{
					[self readInBackgroundAndNotify];
				}];
		}]
		// -readInBackgroundAndNotify must be called on a thread with a run loop,
		// so subscribe on the main thread.
		promiseOnScheduler:RACScheduler.mainThreadScheduler]
		start]
		setNameWithFormat:@"%@ -rac_readInBackground", self];
}

@end
