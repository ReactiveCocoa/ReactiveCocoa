//
//  RACAsyncSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACAsyncSubject.h"
#import "RACSubscriber.h"
#import "RACDisposable.h"

@interface RACAsyncSubject ()

// These should only be read or written while synchronized on self.
@property (nonatomic, strong) id lastValue;
@property (nonatomic, assign) BOOL hasLastValue;
@property (nonatomic, assign) BOOL hasCompletedAlready;
@property (nonatomic, strong) NSError *error;

@end


@implementation RACAsyncSubject


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACDisposable *disposable = [super subscribe:subscriber];

	@synchronized (self) {
		if (self.hasCompletedAlready) {
			[self sendCompleted];
			[disposable dispose];
		} else if (self.error != nil) {
			[self sendError:self.error];
			[disposable dispose];
		}
	}
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	@synchronized (self) {
		self.lastValue = value;
		self.hasLastValue = YES;
	}
}

- (void)sendCompleted {
	@synchronized (self) {
		self.hasCompletedAlready = YES;
		if (self.hasLastValue) [super sendNext:self.lastValue];
	}
	
	[super sendCompleted];
}

- (void)sendError:(NSError *)e {
	@synchronized (self) {
		self.error = e;
	}
	
	[super sendError:e];
}

@end
