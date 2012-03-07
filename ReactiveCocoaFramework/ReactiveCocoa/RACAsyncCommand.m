//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "RACSequence+Private.h"
#import "NSObject+RACPropertyObserving.h"

@interface RACAsyncCommandPair : NSObject

@property (nonatomic, copy) id (^block)(id value, NSError **error);
@property (nonatomic, copy) NSOperation<RACAsyncCommandOperation> * (^operationBlock)(void);
@property (nonatomic, strong) RACValue *value;

+ (id)pair;

@end

@interface RACAsyncCommand ()
@property (nonatomic, readonly) NSMutableArray *asyncFunctionPairs;

+ (NSOperationQueue *)defaultQueue;
@end


@implementation RACAsyncCommand

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.queue = [[self class] defaultQueue];
	self.maxConcurrentExecutions = 1;
	
	return self;
}


#pragma mark RACCommand

- (BOOL)canExecute:(id)value {
	if(self.queue.operationCount >= self.maxConcurrentExecutions) return NO;
	
	return [super canExecute:value];
}

- (void)execute:(id)value {
	if(![self canExecute:value]) return;
	
	[super execute:value];
	
	if(self.asyncFunctionPairs.count > 0) {
		NSAssert(self.queue != nil, @"Queue cannot be nil.");
	}
	
	void (^finish)(RACValue *value, id returnedValue, NSError *error) = ^(RACValue *value, id returnedValue, NSError *error) {
		[[NSOperationQueue mainQueue] addOperationWithBlock:^{
			if(returnedValue != nil) {
				value.value = returnedValue;
			} else {
				[value sendErrorToAllObservers:error];
			}
			
			[value sendCompletedToAllObservers];
		}];
	};
	
	for(RACAsyncCommandPair *pair in self.asyncFunctionPairs) {
		if(pair.block != NULL) {
			[self.queue addOperationWithBlock:^{
				NSError *error = nil;
				id returnedValue = pair.block(value, &error);
				finish(value, returnedValue, error);
			}];
		} else if(pair.operation != nil) {
			pair.operation.RACAsyncCallback = ^(id returnedValue, NSError *error) {
				finish(pair.value, returnedValue, error);
		} else if(pair.operationBlock != nil) {
			NSOperation<RACAsyncCommandOperation> *operation = pair.operationBlock();
			operation.RACAsyncCallback = ^(id returnedValue, BOOL success, NSError *error) {
			};
			
			[self.queue addOperation:operation];
		}
	}
}


#pragma mark API

@synthesize queue;
@synthesize asyncFunctionPairs;
@synthesize maxConcurrentExecutions;

+ (NSOperationQueue *)defaultQueue {
	static dispatch_once_t onceToken;
	static NSOperationQueue *queue = nil;
	dispatch_once(&onceToken, ^{
		queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	});
	
	return queue;
}

- (RACValue *)addAsyncFunction:(id (^)(id value, NSError **error))block {
	NSParameterAssert(block != NULL);
	
	RACValue *value = [RACValue value];
	RACAsyncCommandPair *pair = [RACAsyncCommandPair pair];
	pair.block = block;
	pair.value = value;
	[self.asyncFunctionPairs addObject:pair];
	return value;
}

- (RACValue *)addOperationBlock:(NSOperation<RACAsyncCommandOperation> * (^)(void))operationBlock {
	NSParameterAssert(operationBlock != NULL);
	
	RACValue *value = [RACValue value];
	RACAsyncCommandPair *pair = [RACAsyncCommandPair pair];
	pair.operationBlock = operationBlock;
	pair.value = value;
	[self.asyncFunctionPairs addObject:pair];
	return value;
}

- (NSMutableArray *)asyncFunctionPairs {
	if(asyncFunctionPairs == nil) {
		asyncFunctionPairs = [NSMutableArray array];
	}
	
	return asyncFunctionPairs;
}

- (void)setQueue:(NSOperationQueue *)q {
	if(queue == q) return;
	
	queue = q;
	
	[[RACObservable(self.queue.operationCount) 
		select:^(id _) { return [NSNumber numberWithBool:self.queue.operationCount < self.maxConcurrentExecutions]; }]
		subscribeNext:^(id x) { self.canExecuteValue.value = x; }];
}

@end


@implementation RACAsyncCommandPair


#pragma mark API

@synthesize block;
@synthesize value;
@synthesize operationBlock;

+ (id)pair {
	return [[self alloc] init];
}

@end
