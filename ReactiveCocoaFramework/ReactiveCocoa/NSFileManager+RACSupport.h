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
// If the file at the URL is overwritten, it will re-register for events for the
// new file and continue watching.
//
// Take care when watching bundles. Events can be delivered before the bundle is
// done being written. The FSEvents API might be a better alternative for that
// case.
//
// scheduler - the scheduler that should be used to send values on the returned
// subscribable. Should not be nil.
+ (RACSubscribable *)rac_watchForEventsForFileAtURL:(NSURL *)URL scheduler:(RACScheduler *)scheduler;

@end
