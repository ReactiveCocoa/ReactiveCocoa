//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "RACCommand+Private.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACAsyncSubject.h"
#import "RACReplaySubject.h"

@interface RACAsyncBlockPair : NSObject
@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACAsyncSubject * (^asyncBlock)(id value);

+ (id)pair;
@end

@interface RACAsyncCommand ()
@property (nonatomic, readonly) NSMutableArray *asyncFunctionPairs;
@property (assign) NSUInteger numberOfActiveExecutions;
@end


@implementation RACAsyncCommand

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.maxConcurrentExecutions = 1;
	self.operationQueue = [[self class] defaultOperationQueue];
	
	return self;
}


#pragma mark RACCommand

- (BOOL)canExecute:(id)value {
	if(![super canExecute:value]) return NO;
	if(self.numberOfActiveExecutions >= self.maxConcurrentExecutions) return NO;

	return YES;
}

- (void)execute:(id)value {	
	[super execute:value];
	
	self.numberOfActiveExecutions++;
	
	NSUInteger valuesExpected = self.asyncFunctionPairs.count;
	__block NSUInteger valuesReceived = 0;
	
	void (^didComplete)(void) = ^{
		valuesReceived++;
		
		if(valuesReceived >= valuesExpected) {
			if(self.numberOfActiveExecutions > 0) self.numberOfActiveExecutions--;
		}
	};
	
	for(RACAsyncBlockPair *pair in self.asyncFunctionPairs) {
		[self.operationQueue addOperationWithBlock:^{
			RACAsyncSubject *subject = pair.asyncBlock(value);
			[subject subscribeNext:^(id x) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[pair.subject sendNext:x];
					didComplete();
				});
			} error:^(NSError *error) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[pair.subject sendError:error];
					didComplete();
				});
			} completed:^{
				dispatch_async(dispatch_get_main_queue(), ^{
					[pair.subject sendCompleted];
					didComplete();
				});
			}];
		}];
	}
}


#pragma mark API

@synthesize asyncFunctionPairs;
@synthesize maxConcurrentExecutions;
@synthesize numberOfActiveExecutions;
@synthesize operationQueue;

+ (NSOperationQueue *)defaultOperationQueue {
	NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
	[operationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	[operationQueue setName:@"RACAsyncCommandOperationQueue"];
	return operationQueue;
}

- (RACSubscribable *)addAsyncBlock:(RACAsyncSubject * (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACSubject *subject = [RACSubject subject];
	RACAsyncBlockPair *pair = [RACAsyncBlockPair pair];
	pair.asyncBlock = block;
	pair.subject = subject;
	[self.asyncFunctionPairs addObject:pair];
	return subject;
}

- (NSMutableArray *)asyncFunctionPairs {
	if(asyncFunctionPairs == nil) {
		asyncFunctionPairs = [NSMutableArray array];
	}
	
	return asyncFunctionPairs;
}

@end


@implementation RACAsyncBlockPair

@synthesize subject;
@synthesize asyncBlock;

+ (id)pair {
	return [[self alloc] init];
}

@end
