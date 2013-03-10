//
//  RACObserver.m
//  ReactiveCocoa
//
//  Created by Brian Semiglia on 3/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACObserver.h"

@interface RACObserver ()
@property (nonatomic, strong) id observedObject;
@end

@implementation RACObserver

+ (id)newObserver
{
	return [super init];
}

- (void)observeObject:(id)object
	withUpdateHandler:(void (^)(id object))updateHandler
{
	self.observedObject = object;
	[RACAble(self.observedObject) observerWithUpdateHandler:updateHandler];
}

- (void)observeObject:(id)object
	withUpdateHandler:(void (^)(id object))updateHandler
  deallocationHandler:(void (^)(void))deallocationHandler
{
	self.observedObject = object;
	[RACAble(self.observedObject) observerWithUpdateHandler:updateHandler
										  completionHandler:deallocationHandler];
}

- (void)observeObject:(id)object
	withUpdateHandler:(void (^)(id object))updateHandler
		 errorHandler:(void (^)(NSError *error))errorHandler
	deallocationHandler:(void (^)(void))deallocationHandler
{
	self.observedObject = object;
	[RACAble(self.observedObject) observerWithUpdateHandler:updateHandler
										  completionHandler:deallocationHandler];
}

@end
