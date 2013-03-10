//
//  NSObject+Observer.m
//  ReactiveCocoa
//
//  Created by Brian Semiglia on 3/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+Observer.h"
#import "RACObserver.h"

@implementation NSObject (Observer)

- (void)addobserver:(id)observer
  withUpdateHandler:(void (^)(id))updateHandler
{
	[self.observer observeObject:self
			   withUpdateHandler:updateHandler];
}

- (void)addobserver:(id)observer
  withUpdateHandler:(void (^)(id))updateHandler
deallocationHandler:(void (^)(void))deallocationHandler
{
	[self.observer observeObject:self
			   withUpdateHandler:updateHandler
			 deallocationHandler:deallocationHandler];
}

- (void)addobserver:(id)observer
  withUpdateHandler:(void (^)(id))updateHandler
		 errorHandler:(void (^)(NSError *error))errorHandler
  deallocationHandler:(void (^)(void))deallocationHandler
{
	[self.observer observeObject:self
			   withUpdateHandler:updateHandler
					errorHandler:errorHandler
			 deallocationHandler:deallocationHandler];
}

- (id)observer
{
	static RACObserver *observer;
	if (!observer)
		observer = [RACObserver newObserver];
	
	return observer;
}

@end
