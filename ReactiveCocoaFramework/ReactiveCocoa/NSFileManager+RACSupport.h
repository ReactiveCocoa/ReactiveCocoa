//
//  NSFileManager+RACSupport.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveCocoa/ReactiveCocoa.h>

extern NSString * const RACNSFileManagerErrorDomain;

// An error occurred while trying to open the file at the URL.
extern const NSInteger RACNSFileManagerErrorCouldNotOpenFile;

// An error occurred while trying to create an event source for the file at the
// URL.
extern const NSInteger RACNSFileManagerErrorCouldNotCreateEventSource;

@interface NSFileManager (RACSupport)

// Creates a new subscribable that sends `URL` when the file changes. It sends
// an error if a problem occurred trying to watch the file, and sends completed
// if the file was deleted.
//
// Take care when watching bundles. Events can be delivered before the bundle is
// done being written. The FSEvents API might be a better alternative for that
// case.
//
// queue - the dispatch queue to which the event blocks are submitted. If NULL,
// the default priority global queue is used.
+ (RACSubscribable *)rac_watchForEventsForFileAtURL:(NSURL *)URL queue:(dispatch_queue_t)queue;

@end
