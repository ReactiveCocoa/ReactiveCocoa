//
//  NSFileHandle+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSFileHandle+RACSupport.h"
#import "NSNotificationCenter+RACSupport.h"
#import <libkern/OSAtomic.h>
#import <fcntl.h>

NSString * const RACNSFileHandleErrorDomain = @"com.github.ReactiveCocoa.NSFileHandle";

const NSInteger RACNSFileHandleErrorInvalidFileDescriptor = 666;
const NSInteger RACNSFileHandleErrorCouldNotCreateEventSource = 667;

@implementation NSFileHandle (RACSupport)

- (RACSubscribable *)rac_readInBackground {
	RACReplaySubject *subject = [RACReplaySubject subject];
	RACSubscribable *dataNotification = [[[NSNotificationCenter defaultCenter] rac_addObserverForName:NSFileHandleReadCompletionNotification object:self] select:^(NSNotification *note) {
		return [note.userInfo objectForKey:NSFileHandleNotificationDataItem];
	}];
	
	__block RACDisposable *subscription = [dataNotification subscribeNext:^(NSData *data) {
		if(data.length > 0) {
			[subject sendNext:data];
			[self readInBackgroundAndNotify];
		} else {
			[subject sendCompleted];
			[subscription dispose];
		}
	}];
	
	[self readInBackgroundAndNotify];
	
	return subject;
}

+ (instancetype)rac_fileHandleForEventsWithFileAtURL:(NSURL *)URL error:(NSError **)error {
	int fd = open(URL.path.fileSystemRepresentation, O_EVTONLY);
	if (fd < 0) {
		if (error != NULL) {
			const char *errorMessage = strerror(errno);
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @(errorMessage) };
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
		}
		
		return nil;
	}

	return [[self alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
}

- (RACSubscribable *)rac_watchForEventsWithQueue:(dispatch_queue_t)queue {
	if (self.fileDescriptor < 0) return [RACSubscribable error:[NSError errorWithDomain:RACNSFileHandleErrorDomain code:RACNSFileHandleErrorInvalidFileDescriptor userInfo:nil]];

	return [RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
		dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t) self.fileDescriptor, DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, queue ? : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
		if (source == NULL) {
			[subscriber sendError:[NSError errorWithDomain:RACNSFileHandleErrorDomain code:RACNSFileHandleErrorCouldNotCreateEventSource userInfo:nil]];
			return nil;
		}

		dispatch_source_set_event_handler(source, ^{
			[subscriber sendNext:self];
		});

		__block volatile uint32_t disposed = 0;
		dispatch_source_set_cancel_handler(source, ^{
			if (disposed == 0) {
				[subscriber sendCompleted];
			}

			dispatch_release(source);
		});

		dispatch_resume(source);

		return [RACDisposable disposableWithBlock:^{
			OSAtomicOr32Barrier(1, &disposed);
			dispatch_source_cancel(source);
		}];
	}];
}

@end
