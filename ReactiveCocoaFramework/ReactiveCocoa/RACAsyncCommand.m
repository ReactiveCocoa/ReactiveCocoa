//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACScheduler.h"
#import "RACTuple.h"

@interface RACAsyncBlockPair : NSObject
@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACSubscribable * (^asyncBlock)(id value);
@end

@interface RACAsyncCommand ()
@property (nonatomic, readonly, strong) NSMutableArray *asyncFunctionPairs;
@property (assign) NSUInteger numberOfActiveExecutions;
@end

@implementation RACAsyncCommand

- (id)init {
	self = [super init];
	if (self == nil) return nil;
	
	_maxConcurrentExecutions = 1;
	_operationQueue = [[self class] defaultOperationQueue];
	_asyncFunctionPairs = [NSMutableArray array];
	
	return self;
}


#pragma mark RACCommand

- (id)initWithCanExecuteSubscribable:(id<RACSubscribable>)canExecuteSubscribable block:(void (^)(id sender))block {
	self = [super initWithCanExecuteSubscribable:nil block:block];
	if (self == nil) return nil;
	
	[[RACSubscribable
		combineLatest:@[ canExecuteSubscribable ? : [RACSubscribable return:@(YES)], RACAbleWithStart(self.numberOfActiveExecutions), RACAbleWithStart(self.maxConcurrentExecutions) ]
		reduce:^(RACTuple *xs) {
			NSNumber *canExecute = xs.first;
			NSNumber *executions = xs.second;
			NSNumber *maxConcurrent = xs.third;
			return @(canExecute.boolValue && executions.unsignedIntegerValue < maxConcurrent.unsignedIntegerValue);
		}]
		toProperty:RAC_KEYPATH_SELF(self.canExecute) onObject:self];
	
	return self;
}

- (BOOL)execute:(id)sender {
	BOOL didExecute = [super execute:sender];
	if (!didExecute) return NO;
	
	self.numberOfActiveExecutions++;
	
	NSArray *subscribables = [self.asyncFunctionPairs valueForKeyPath:@"subject"];
	[[[RACSubscribable
		merge:subscribables]
		finally:^{
			self.numberOfActiveExecutions--;
		}]
		subscribeNext:^(id _) {
			// nothing bro
		}];
	
	for (RACAsyncBlockPair *pair in self.asyncFunctionPairs) {
		[self.operationQueue addOperationWithBlock:^{
			[pair.asyncBlock(sender) subscribeNext:^(id x) {
				[pair.subject sendNext:x];
			} error:^(NSError *error) {
				[pair.subject sendError:error];
			} completed:^{
				[pair.subject sendCompleted];
			}];
		}];
	}
	
	return YES;
}


#pragma mark API

+ (NSOperationQueue *)defaultOperationQueue {
	NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
	[operationQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	[operationQueue setName:@"RACAsyncCommandOperationQueue"];
	return operationQueue;
}

- (RACSubscribable *)addAsyncBlock:(RACSubscribable * (^)(id value))block {
	NSParameterAssert(block != NULL);
	
	RACSubject *subject = [RACSubject subject];
	RACAsyncBlockPair *pair = [[RACAsyncBlockPair alloc] init];
	pair.asyncBlock = block;
	pair.subject = subject;
	[self.asyncFunctionPairs addObject:pair];
	return subject;
}

@end


@implementation RACAsyncBlockPair

@end
