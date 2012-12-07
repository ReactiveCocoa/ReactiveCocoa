//
//  RACScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACScheduler+Private.h"
#import "RACDisposable.h"
#import "RACQueueScheduler.h"
#import "RACImmediateScheduler.h"
#import "RACIterativeScheduler.h"
#import "RACDeferredScheduler.h"
#import "RACSubscriptionScheduler.h"

// The key for the queue-specific current scheduler.
const void *RACSchedulerCurrentSchedulerKey = &RACSchedulerCurrentSchedulerKey;

@interface RACScheduler ()
@property (nonatomic, readonly, copy) NSString *name;
@end

@implementation RACScheduler

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.name];
}

#pragma mark Initializers

- (id)initWithName:(NSString *)name {
	self = [super init];
	if (self == nil) return nil;

	_name = [name ?: @"com.ReactiveCocoa.RACScheduler.anonymousScheduler" copy];

	return self;
}

- (id)init {
	return [self initWithName:nil];
}

#pragma mark Schedulers

+ (instancetype)immediateScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *immediateScheduler;
	dispatch_once(&onceToken, ^{
		immediateScheduler = [[RACImmediateScheduler alloc] init];
	});
	
	return immediateScheduler;
}

+ (instancetype)iterativeScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *iterativeScheduler;
	dispatch_once(&onceToken, ^{
		iterativeScheduler = [[RACIterativeScheduler alloc] init];
	});

	return iterativeScheduler;
}

+ (instancetype)mainThreadScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *mainThreadScheduler;
	dispatch_once(&onceToken, ^{
		mainThreadScheduler = [[RACQueueScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.mainThreadScheduler" targetQueue:dispatch_get_main_queue()];
	});
	
	return mainThreadScheduler;
}

+ (instancetype)deferredScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *deferredScheduler;
	dispatch_once(&onceToken, ^{
		deferredScheduler = [[RACDeferredScheduler alloc] init];
	});
	
	return deferredScheduler;
}

+ (instancetype)backgroundSchedulerWithPriority:(RACSchedulerPriority)priority {
	return [[RACQueueScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.backgroundScheduler" targetQueue:dispatch_get_global_queue(priority, 0)];
}

+ (instancetype)backgroundScheduler {
	return [self backgroundSchedulerWithPriority:RACSchedulerPriorityDefault];
}

+ (instancetype)subscriptionScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *subscriptionScheduler;
	dispatch_once(&onceToken, ^{
		subscriptionScheduler = [[RACSubscriptionScheduler alloc] init];
	});

	return subscriptionScheduler;
}

+ (BOOL)isOnMainThread {
	return [NSOperationQueue.currentQueue isEqual:NSOperationQueue.mainQueue] || [NSThread isMainThread];
}

+ (instancetype)currentScheduler {
	RACScheduler *scheduler = (__bridge id)dispatch_get_specific(RACSchedulerCurrentSchedulerKey);
	if (scheduler != nil) return scheduler;
	if ([self.class isOnMainThread]) return RACScheduler.mainThreadScheduler;

	return nil;
}

#pragma mark Scheduling

- (void)schedule:(void (^)(void))block {
	NSAssert(NO, @"-schedule: must be implemented by a subclass.");
}

@end
