//
//  RACAsyncCommand.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncCommand.h"
#import "RACCommand+Private.h"
#import "RACSequence+Private.h"
#import "NSObject+RACPropertyObserving.h"

@interface RACAsyncFunctionPair : NSObject
@property (nonatomic, strong) RACValue *value;
@property (nonatomic, strong) RACSequence * (^asyncFunction)(id value);

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
	
	for(RACAsyncFunctionPair *pair in self.asyncFunctionPairs) {
		[self.operationQueue addOperationWithBlock:^{
			RACSequence *sequence = pair.asyncFunction(value);
			[sequence subscribeNext:^(id x) {
				dispatch_async(dispatch_get_main_queue(), ^{
					pair.value.value = x;
					didComplete();
				});
			} error:^(NSError *error) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[pair.value sendErrorToAllObservers:error];
					didComplete();
				});
			} completed:^{
				dispatch_async(dispatch_get_main_queue(), ^{
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

- (RACValue *)addAsyncFunction:(RACSequence * (^)(id value))function {
	NSParameterAssert(function != NULL);
	
	RACValue *value = [RACValue value];
	RACAsyncFunctionPair *pair = [RACAsyncFunctionPair pair];
	pair.asyncFunction = function;
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

@end


@implementation RACAsyncFunctionPair

@synthesize value;
@synthesize asyncFunction;

+ (id)pair {
	return [[self alloc] init];
}

@end
