//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "RACObservableSequence+Private.h"

@interface RACAsyncCommandPair : NSObject

@property (nonatomic, readonly, copy) RACObservableSequence * (^block)(id value);
@property (nonatomic, readonly, strong) RACObservableSequence *sequence;

+ (id)pairWithBlock:(RACObservableSequence * (^)(id value))block sequence:(RACObservableSequence *)sequence;

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
			id returnedValue = pair.block(value);
			[[NSOperationQueue mainQueue] addOperationWithBlock:^{
				[pair.sequence addObjectAndNilsAreOK:returnedValue];
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

- (RACObservableSequence *)addAsyncFunction:(RACObservableSequence * (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACObservableSequence *sequence = [RACObservableSequence sequence];
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


@interface RACAsyncCommandPair ()
@property (nonatomic, copy) RACObservableSequence * (^block)(id value);
@property (nonatomic, strong) RACObservableSequence *sequence;
@end


@implementation RACAsyncCommandPair


#pragma mark API

@synthesize block;
@synthesize sequence;

+ (id)pairWithBlock:(RACObservableSequence * (^)(id value))block sequence:(RACObservableSequence *)sequence {
	RACAsyncCommandPair *pair = [[self alloc] init];
	pair.block = block;
	pair.sequence = sequence;
	return pair;
}

@end
