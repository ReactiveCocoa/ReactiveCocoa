//
//  NSObject+GHExtensions.m
//  GitHub
//
//  Created by Josh Abernathy on 12/8/10.
//  Copyright 2010 GitHub. All rights reserved.
//

#import "NSObject+GHExtensions.h"


@implementation NSObject (GHExtensions)

- (id)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay {
	id blockCopy = [block copy];
    [self performSelector:@selector(reallyPerformBlock:) withObject:blockCopy afterDelay:delay];
	return blockCopy;
}

- (void)reallyPerformBlock:(void (^)(void))block {
    block();
}

- (void)cancelPreviousPerformBlockRequestsWithId:(id)blockId {
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(reallyPerformBlock:) object:blockId];
}

- (void)performBlockOnMainThread:(void (^)(void))block {
	dispatch_async(dispatch_get_main_queue(), block);
}

- (void)performBlockInBackground:(void (^)(void))block {
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

@end
