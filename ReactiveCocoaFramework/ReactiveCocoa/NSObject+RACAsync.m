//
//  NSObject+RACAsync.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACAsync.h"
#import "RACAsyncSubject.h"


@implementation NSObject (RACAsync)

+ (id<RACSubscribable>)RACAsync:(id (^)(void))block {
	NSParameterAssert(block != NULL);
	
	RACAsyncSubject *subject = [RACAsyncSubject subject];
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[subject sendNext:block()];
		[subject sendCompleted];
	});
	
	return subject;
}

@end
