//
//  NSObject+GHExtensions.h
//  GitHub
//
//  Created by Josh Abernathy on 12/8/10.
//  Copyright 2010 GitHub. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (GHExtensions)
/**
 * Queues the passed in block for execution after delay.
 *
 * Returns an object to identify this queued perform block. You shouldn't use this object for anything other than passing into -[NSObject cancelPreviousPerformBlockRequestsWithId:].
 */
- (id)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;

/**
 * Cancels the queued perform block associated with that block id. The block id should be the return value from the original -[NSObject performBlock:afterDelay:] call.
 */
- (void)cancelPreviousPerformBlockRequestsWithId:(id)blockId;

- (void)performBlockOnMainThread:(void (^)(void))block;
- (void)performBlockInBackground:(void (^)(void))block;
@end
