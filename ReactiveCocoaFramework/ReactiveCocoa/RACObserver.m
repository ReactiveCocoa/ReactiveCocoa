//
//  RACObserver.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACObserver.h"

@interface RACObserver ()
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);
@end


@implementation RACObserver


#pragma mark API

@synthesize next;
@synthesize error;
@synthesize completed;

+ (id)observerWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACObserver *observer = [[self alloc] init];
	observer.next = next;
	observer.error = error;
	observer.completed = completed;
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
