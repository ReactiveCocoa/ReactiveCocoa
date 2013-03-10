//
//  RACObserver.h
//  ReactiveCocoa
//
//  Created by Brian Semiglia on 3/10/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

@interface RACObserver : RACSignal

+ (id)newObserver;

- (void)observeObject:(id)object
	withUpdateHandler:(void(^)(id object))updateHandler;

- (void)observeObject:(id)object
	withUpdateHandler:(void (^)(id object))updateHandler
	deallocationHandler:(void (^)(void))deallocationHandler;

- (void)observeObject:(id)object
	withUpdateHandler:(void (^)(id object))updateHandler
		 errorHandler:(void (^)(NSError *error))errorHandler
	deallocationHandler:(void (^)(void))deallocationHandler;

@end
