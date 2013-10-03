//
//  NSURLConnection+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSURLConnection+RACSupport.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import "RACTuple.h"

@implementation NSURLConnection (RACSupport)

+ (RACSignal *)rac_sendAsynchronousRequest:(NSURLRequest *)request {
	NSCParameterAssert(request != nil);

	return [[RACSignal
		createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			NSOperationQueue *queue = [[NSOperationQueue alloc] init];
			queue.name = @"com.github.ReactiveCocoa.NSURLConnectionRACSupport";

			[NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
				if (data == nil) {
					[subscriber sendError:error];
				} else {
					[subscriber sendNext:RACTuplePack(response, data)];
					[subscriber sendCompleted];
				}
			}];

			return [RACDisposable disposableWithBlock:^{
				// It's not clear if this will actually cancel the connection,
				// but we can at least prevent _some_ unnecessary work --
				// without writing all the code for a proper delegate, which
				// doesn't really belong in RAC.
				queue.suspended = YES;
				[queue cancelAllOperations];
			}];
		}]
		setNameWithFormat:@"+rac_sendAsynchronousRequest: %@", request];
}

@end
