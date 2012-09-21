//
//  NSFileManager+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSFileManager+RACSupport.h"
#import <fcntl.h>
#import <libkern/OSAtomic.h>

NSString * const RACNSFileManagerErrorDomain = @"com.github.ReactiveCocoa.NSFileManager";

const NSInteger RACNSFileManagerErrorCouldNotOpenFile = 666;
const NSInteger RACNSFileManagerErrorCouldNotCreateEventSource = 667;

@implementation NSFileManager (RACSupport)

+ (RACSubscribable *)rac_watchForEventsForFileAtURL:(NSURL *)URL scheduler:(RACScheduler *)scheduler {
	NSParameterAssert(scheduler != nil);

	return [[RACSubscribable createSubscribable:^ id (id<RACSubscriber> subscriber) {
		__block dispatch_source_t currentSource = NULL;
		__block uint32_t volatile disposed = 0;

		__block BOOL (^startWatchingURL)(NSError **);
		void (^eventHandler)(void) = ^{
			if (disposed == 1) return;

			[subscriber sendNext:URL];

			unsigned long flags = dispatch_source_get_data(currentSource);
			// When the file's been deleted, we should try to re-watch in case
			// it was simply overwritten. If we can't, then the file must have
			// really been deleted and we can complete.
			if ((flags & DISPATCH_VNODE_DELETE) != 0) {
				dispatch_source_cancel(currentSource);
				currentSource = NULL;

				NSError *error = nil;
				BOOL success = startWatchingURL(&error);
				if (!success) {
					if ([error.domain isEqual:RACNSFileManagerErrorDomain] && error.code == RACNSFileManagerErrorCouldNotOpenFile) {
						[subscriber sendCompleted];
					} else {
						[subscriber sendError:error];
					}
				}
			}
		};

		startWatchingURL = ^(NSError **error) {
			int fd = open(URL.path.fileSystemRepresentation, O_EVTONLY);
			if (fd < 0) {
				if (error != NULL) {
					*error = [NSError errorWithDomain:RACNSFileManagerErrorDomain code:RACNSFileManagerErrorCouldNotOpenFile userInfo:nil];
				}
				return NO;
			}

			dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, (uintptr_t) fd, DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
			if (source == NULL) {
				close(fd);
				if (error != NULL) {
					*error = [NSError errorWithDomain:RACNSFileManagerErrorDomain code:RACNSFileManagerErrorCouldNotCreateEventSource userInfo:nil];
				}
				return NO;
			}

			dispatch_source_set_event_handler(source, eventHandler);
			dispatch_source_set_cancel_handler(source, ^{
				int fd = (int) dispatch_source_get_handle(source);
				dispatch_release(source);
				close(fd);
			});
			dispatch_resume(source);

			currentSource = source;

			return YES;
		};

		NSError *error = nil;
		BOOL success = startWatchingURL(&error);
		if (!success) {
			[subscriber sendError:error];
		}

		return [RACDisposable disposableWithBlock:^{
			OSAtomicOr32Barrier(1, &disposed);

			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
				if (currentSource == NULL) return;
				
				dispatch_source_cancel(currentSource);
				currentSource = NULL;
			});
		}];
	}] deliverOn:scheduler];
}

@end
