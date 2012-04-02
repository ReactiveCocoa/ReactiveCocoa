//
//  NSObject+RACExtensions.m
//  GitHub
//
//  Created by Josh Abernathy on 12/8/10.
//  Copyright 2010 GitHub. All rights reserved.
//

#import "NSObject+RACExtensions.h"


@implementation NSObject (RACExtensions)

- (id)rac_performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay {
	id blockCopy = [block copy];
    [self performSelector:@selector(rac_reallyPerformBlock:) withObject:blockCopy afterDelay:delay];
	return blockCopy;
}

- (void)rac_reallyPerformBlock:(void (^)(void))block {
    block();
}

- (void)rac_cancelPreviousPerformBlockRequestsWithId:(id)blockId {
	[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(reallyPerformBlock:) object:blockId];
}

@end
