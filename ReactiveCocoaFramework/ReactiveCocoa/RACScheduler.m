//
//  RACScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACImmediateScheduler.h"
#import "RACQueueScheduler.h"
#import "RACScheduler+Private.h"
#import "RACSubscriptionScheduler.h"
#import <libkern/OSAtomic.h>

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

#pragma mark Schedulers

+ (instancetype)immediateScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *immediateScheduler;
	dispatch_once(&onceToken, ^{
		immediateScheduler = [[RACImmediateScheduler alloc] init];
	});
	
	return immediateScheduler;
}

+ (instancetype)mainThreadScheduler {
	static dispatch_once_t onceToken;
	static RACScheduler *mainThreadScheduler;
	dispatch_once(&onceToken, ^{
		mainThreadScheduler = [[RACQueueScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.mainThreadScheduler" targetQueue:dispatch_get_main_queue()];
	});
	
	return mainThreadScheduler;
}

+ (instancetype)schedulerWithPriority:(RACSchedulerPriority)priority {
	return [[RACQueueScheduler alloc] initWithName:@"com.ReactiveCocoa.RACScheduler.backgroundScheduler" targetQueue:dispatch_get_global_queue(priority, 0)];
}

+ (instancetype)scheduler {
	return [self schedulerWithPriority:RACSchedulerPriorityDefault];
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

- (RACDisposable *)schedule:(void (^)(void))block {
	NSAssert(NO, @"-schedule: must be implemented by a subclass.");
	return nil;
}

- (RACDisposable *)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock {
	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];

	__block volatile uint32_t disposed = 0;
	BOOL (^isDisposed)(void) = [^{
		return disposed != 0;
	} copy];

	[disposable addDisposable:[RACDisposable disposableWithBlock:^{
		OSAtomicOr32Barrier(1, &disposed);
	}]];

	[self scheduleRecursiveBlock:[recursiveBlock copy] addingToDisposable:disposable isDisposedBlock:isDisposed];
	return disposable;
}

- (void)scheduleRecursiveBlock:(RACSchedulerRecursiveBlock)recursiveBlock addingToDisposable:(RACCompoundDisposable *)disposable isDisposedBlock:(BOOL (^)(void))isDisposed {
	RACDisposable *schedulingDisposable = [self schedule:^{
		if (isDisposed()) return;

		__block NSUInteger rescheduleCount = 0;
		recursiveBlock(^{
			++rescheduleCount;
		});

		for (NSUInteger i = 0; i < rescheduleCount; i++) {
			if (isDisposed()) return;

			[self scheduleRecursiveBlock:recursiveBlock addingToDisposable:disposable isDisposedBlock:isDisposed];
		}
	}];

	if (schedulingDisposable != nil) [disposable addDisposable:schedulingDisposable];
}

@end
