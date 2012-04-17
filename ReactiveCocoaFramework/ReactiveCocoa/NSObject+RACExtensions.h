//
//  NSObject+RACExtensions.h
//  GitHub
//
//  Created by Josh Abernathy on 12/8/10.
//  Copyright 2010 GitHub. All rights reserved.
//


@interface NSObject (RACExtensions)

// Queues the passed in block for execution after delay.
//
// Returns an object to identify this queued perform block. You shouldn't use this object for anything other than passing into -[NSObject cancelPreviousPerformBlockRequestsWithId:].
- (id)rac_performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;

// Cancels the queued perform block associated with that block id. The block id should be the return value from the original -[NSObject performBlock:afterDelay:] call.
- (void)rac_cancelPreviousPerformBlockRequestsWithId:(id)blockId;

@end
