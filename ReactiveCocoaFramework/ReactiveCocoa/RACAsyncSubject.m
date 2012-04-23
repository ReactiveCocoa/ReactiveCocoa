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
@end


@implementation RACAsyncSubject


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACDisposable * disposable = [super subscribe:subscriber];
	if(self.hasCompletedAlready) {
		[self sendCompleted];
	}
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	self.lastValue = value;
}

- (void)sendCompleted {
	self.hasCompletedAlready = YES;
	
	[super sendNext:self.lastValue];
	[super sendCompleted];
}


#pragma mark API

@synthesize lastValue;
@synthesize hasCompletedAlready;

@end
