//
//  NSFileHandle+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

extern NSString * const RACNSFileHandleErrorDomain;

// The file handle does not have a valid file descriptor and so it cannot be
// watched for events.
extern const NSInteger RACNSFileHandleErrorInvalidFileDescriptor;

// An error occurred while trying to create an event source with the receiver's
// file descriptor.
extern const NSInteger RACNSFileHandleErrorCouldNotCreateEventSource;

@interface NSFileHandle (RACSupport)

// Read any available data in the background and send it. Completes when data
// length is <= 0.
- (RACSubscribable *)rac_readInBackground;

// Creates a new file handle which opens the URL for event notification only.
// This is meant to be used in combination with `-rac_watchForEventsWithQueue:`.
+ (instancetype)rac_fileHandleForEventsWithFileAtURL:(NSURL *)URL error:(NSError **)error;

// Creates a new subscribable that sends `self` when the file represented by the
// receiver's `fileDescriptor` changes. The receiver must have a valid file
// descriptor or an error will be sent with the domain
// `RACNSFileHandleErrorDomain` and code
// `RACNSFileHandleErrorInvalidFileDescriptor`.
//
// Note: The file handle is kept alive until the subscription is disposed of or
// the file handle is closed.
//
// queue - the dispatch queue to which the event blocks are submitted. If NULL,
// the default priority global queue is used.
- (RACSubscribable *)rac_watchForEventsWithQueue:(dispatch_queue_t)queue;

@end
