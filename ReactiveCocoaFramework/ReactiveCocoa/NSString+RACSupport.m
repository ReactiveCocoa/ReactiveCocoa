//
//  NSString+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSString+RACSupport.h"
#import "RACPromise.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSString (RACSupport)

+ (RACSignal *)rac_readContentsOfURL:(NSURL *)URL usedEncoding:(NSStringEncoding *)encoding scheduler:(RACScheduler *)scheduler {
	NSCParameterAssert(scheduler != nil);
	
	return [[[RACPromise
		promiseWithScheduler:scheduler block:^(id<RACSubscriber> subscriber) {
			NSError *error = nil;
			NSString *string = [NSString stringWithContentsOfURL:URL usedEncoding:encoding error:&error];
			if (string == nil) {
				[subscriber sendError:error];
			} else {
				[subscriber sendNext:string];
				[subscriber sendCompleted];
			}
		}]
		start]
		setNameWithFormat:@"+rac_readContentsOfURL: %@ usedEncoding:scheduler: %@", URL, scheduler];
}

@end
