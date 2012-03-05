//
//  RACOperation.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACOperation.h"
#import "RACObserver.h"
#import "RACObservableSequence+Private.h"

@interface RACOperation ()
@property (nonatomic, copy) id (^executeBlock)(void);
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) RACObservableValue *currentValue;
@end


@implementation RACOperation


#pragma mark NSOperation

- (void)main {
	self.currentValue.value = self.executeBlock();
	
	[self.currentValue performBlockOnAllObservers:^(RACObserver *observer) {
		if(observer.completed != NULL) {
			observer.completed();
		}
	}];
}


#pragma mark API

@synthesize executeBlock;
@synthesize queue;
@synthesize currentValue;

+ (id)operationWithBlock:(id (^)(void))block onQueue:(NSOperationQueue *)queue {
	NSParameterAssert(block != NULL);
	NSParameterAssert(queue != nil);
	
	RACOperation *operation = [[self alloc] init];
	operation.executeBlock = block;
	operation.queue = queue;
	return operation;
}

- (RACObservableValue *)execute {
	self.currentValue = [RACObservableValue value];
	[self.queue addOperation:self];
	
	return self.currentValue;
}

@end
