//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "EXTKeyPathCoding.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"

@interface RACAsyncBlockPair : NSObject
@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACSignal * (^asyncBlock)(id value);
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

- (id)initWithCanExecuteSignal:(RACSignal *)canExecuteSignal block:(void (^)(id sender))block {
	self = [super initWithCanExecuteSignal:nil block:block];
	if (self == nil) return nil;
	
	[[RACSignal
		combineLatest:@[ canExecuteSignal ?: [RACSignal return:@YES], RACAbleWithStart(self.numberOfActiveExecutions), RACAbleWithStart(self.maxConcurrentExecutions) ]
		reduce:^(NSNumber *canExecute, NSNumber *activeExecutions, NSNumber *maxConcurrent) {
			return @(canExecute.boolValue && activeExecutions.unsignedIntegerValue < maxConcurrent.unsignedIntegerValue);
		}]
		toProperty:@keypath(self.canExecute) onObject:self];
	
	return self;
}

- (BOOL)execute:(id)sender {
	BOOL didExecute = [super execute:sender];
	if (!didExecute) return NO;
	
	self.numberOfActiveExecutions++;
	
	NSArray *signals = [self.asyncFunctionPairs valueForKeyPath:@"subject"];
	[[[RACSignal
		merge:signals]
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

- (RACSignal *)addAsyncBlock:(RACSignal * (^)(id value))block {
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
