//
//  RACAsyncSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACAsyncSubject.h"
#import "RACSubscriber.h"

@interface RACAsyncSubject ()
@property (nonatomic, strong) id lastValue;
@property (assign) BOOL hasCompletedAlready;
@property (strong) NSError *error;
@end


@implementation RACAsyncSubject


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACDisposable * disposable = [super subscribe:subscriber];
	if(self.hasCompletedAlready) {
		[self sendCompleted];
	} else if(self.error != nil) {
		[self sendError:self.error];
	}
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	@synchronized(self.lastValue) {
		self.lastValue = value;
	}
}

- (void)sendCompleted {
	self.hasCompletedAlready = YES;
	
	@synchronized(self.lastValue) {
		[super sendNext:self.lastValue];
	}
	
	[super sendCompleted];
}

- (void)sendError:(NSError *)e {
	[super sendError:e];
	
	self.error = e;
}


#pragma mark API

@synthesize lastValue;
@synthesize hasCompletedAlready;
@synthesize error;

@end
