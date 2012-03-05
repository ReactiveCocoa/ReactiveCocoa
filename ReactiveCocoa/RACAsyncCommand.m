//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "RACSequence+Private.h"

@interface RACAsyncCommandPair : NSObject

@property (nonatomic, copy) id (^block)(id value, NSError **error);
@property (nonatomic, strong) RACSequence *sequence;

+ (id)pairWithBlock:(id (^)(id value, NSError **error))block sequence:(RACSequence *)sequence;

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
	self.maxConcurrent = 1;
	
	return self;
}


#pragma mark RACCommand

- (BOOL)canExecute:(id)value {
	if(self.queue.operationCount >= self.maxConcurrent) return NO;
	
	return [super canExecute:value];
}

- (void)execute:(id)value {
	if(![self canExecute:value]) return;
	
	[super execute:value];
	
	NSAssert(self.queue != nil, @"Queue cannot be nil.");
	
	[self.queue addOperationWithBlock:^{
		for(RACAsyncCommandPair *pair in self.asyncFunctionPairs) {
			NSError *error = nil;
			id returnedValue = pair.block(value, &error);
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				if(returnedValue != nil) {
					[pair.sequence addObjectAndNilsAreOK:returnedValue];
				} else {
					[pair.sequence sendErrorToAllObservers:error];
				}
				
				[pair.sequence sendCompletedToAllObservers];
			}];
		}
	}];
}


#pragma mark API

@synthesize queue;
@synthesize asyncFunctionPairs;
@synthesize maxConcurrent;

+ (NSOperationQueue *)defaultQueue {
	static dispatch_once_t onceToken;
	static NSOperationQueue *queue = nil;
	dispatch_once(&onceToken, ^{
		queue = [[NSOperationQueue alloc] init];
		[queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	});
	
	return queue;
}

- (RACSequence *)addAsyncFunction:(id (^)(id value, NSError **error))block {
	NSParameterAssert(block != NULL);
	
	RACSequence *sequence = [RACSequence sequence];
	RACAsyncCommandPair *pair = [RACAsyncCommandPair pairWithBlock:block sequence:sequence];
	[self.asyncFunctionPairs addObject:pair];
	return sequence;
}

- (NSMutableArray *)asyncFunctionPairs {
	if(asyncFunctionPairs == nil) {
		asyncFunctionPairs = [NSMutableArray array];
	}
	
	return asyncFunctionPairs;
}

@end


@implementation RACAsyncCommandPair


#pragma mark API

@synthesize block;
@synthesize sequence;

+ (id)pairWithBlock:(id (^)(id value, NSError **error))block sequence:(RACSequence *)sequence {
	RACAsyncCommandPair *pair = [[self alloc] init];
	pair.block = block;
	pair.sequence = sequence;
	return pair;
}

@end
