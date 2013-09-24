//
//  NSData+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSData+RACSupport.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"

@implementation NSData (RACSupport)

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL options:(NSDataReadingOptions)options scheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);
	
	RACReplaySubject *subject = [RACReplaySubject subject];
	[subject setNameWithFormat:@"+rac_readContentsOfURL: %@ options: %lu scheduler: %@", URL, (unsigned long)options, scheduler];
	
	[scheduler schedule:^{
		NSError *error = nil;
		NSData *data = [[NSData alloc] initWithContentsOfURL:URL options:options error:&error];
		if(data == nil) {
			[subject sendError:error];
		} else {
			[subject sendNext:data];
			[subject sendCompleted];
		}
	}];
	
	return subject;
}

@end
