//
//  RACScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

@interface RACScheduler ()
@property (nonatomic, copy) void (^scheduleBlock)(void (^block)(void));
@end


@implementation RACScheduler


#pragma mark API

@synthesize scheduleBlock;

+ (id)schedulerWithScheduleBlock:(void (^)(void (^block)(void)))scheduleBlock {
	NSParameterAssert(scheduleBlock != NULL);
	
	RACScheduler *scheduler = [[self alloc] init];
	scheduler.scheduleBlock = scheduleBlock;
	return scheduler;
}

+ (id)immediateScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *immediateScheduler = nil;
	dispatch_once(&onceToken, ^{
		immediateScheduler = [RACScheduler schedulerWithScheduleBlock:^(void (^block)(void)) {
			block();
		}];
	});
	
	return immediateScheduler;
}

+ (id)mainQueueScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *mainQueueScheduler = nil;
	dispatch_once(&onceToken, ^{
		mainQueueScheduler = [RACScheduler schedulerWithScheduleBlock:^(void (^block)(void)) {
			dispatch_async(dispatch_get_main_queue(), block);
		}];
	});
	
	return mainQueueScheduler;
}

+ (id)backgroundScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *backgroundScheduler = nil;
	dispatch_once(&onceToken, ^{
		backgroundScheduler = [RACScheduler schedulerWithScheduleBlock:^(void (^block)(void)) {
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
		}];
	});
	
	return backgroundScheduler;
}

+ (id)deferredScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *deferredScheduler = nil;
	dispatch_once(&onceToken, ^{
		deferredScheduler = [RACScheduler schedulerWithScheduleBlock:^(void (^block)(void)) {
			dispatch_async(dispatch_get_current_queue(), block);
		}];
	});
	
	return deferredScheduler;
}

+ (id)operationQueueScheduler {
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	[queue setName:@"RACOperationQueueSchedulerQueue"];
	return [self schedulerWithOperationQueue:queue];
}

+ (id)sharedOperationQueueScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *sharedOperationQueueScheduler = nil;
	dispatch_once(&onceToken, ^{
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
		[queue setName:@"RACSharedOperationQueueSchedulerQueue"];
		sharedOperationQueueScheduler = [self schedulerWithOperationQueue:queue];
	});
	
	return sharedOperationQueueScheduler;
}

+ (id)schedulerWithOperationQueue:(NSOperationQueue *)queue {
	return [RACScheduler schedulerWithScheduleBlock:^(void (^block)(void)) {
		[queue addOperationWithBlock:block];
	}];
}

- (void)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	if(self.scheduleBlock != NULL) {
		self.scheduleBlock(block);
	}
}

@end
