//
//  RACObserver.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObserver.h"

@interface RACObserver ()
@property (nonatomic, copy) void (^completed)(void);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^next)(id value);
@end


@implementation RACObserver


#pragma mark API

@synthesize completed;
@synthesize next;
@synthesize error;

+ (id)observerWithCompleted:(void (^)(void))completed error:(void (^)(NSError *error))error next:(void (^)(id value))next {
	RACObserver *observer = [[self alloc] init];
	observer.completed = completed;
	observer.error = error;
	observer.next = next;
	return observer;
}

- (void)sendNext:(id)value {
	if(self.next != NULL) {
		self.next(value);
	}
}

- (void)sendError:(NSError *)e {
	if(self.error != NULL) {
		self.error(e);
	}
}

- (void)sendCompleted {
	if(self.completed != NULL) {
		self.completed();
	}
}

@end
