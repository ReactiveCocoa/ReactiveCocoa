//
//  RACAsyncSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACAsyncSubject.h"
#import "RACSequence+Private.h"
#import "RACObserver.h"

@interface RACAsyncSubject ()
@property (nonatomic, strong) id lastValue;
@property (nonatomic, assign) BOOL hasCompleted;
@end


@implementation RACAsyncSubject


#pragma mark RACObservable

- (id)subscribe:(RACObserver *)observer {
	id result = [super subscribe:observer];
	if(self.hasCompleted) {
		[self sendCompletedToAllObservers];
	}
	
	return result;
}


#pragma mark RACSequence

- (void)addObjectAndNilsAreOK:(id)object {	
	self.lastValue = object;
}

- (void)sendCompletedToAllObservers {
	self.hasCompleted = YES;
	
	[self sendNextToAllObservers:self.lastValue];
	[super sendCompletedToAllObservers];
}


#pragma mark API

@synthesize lastValue;
@synthesize hasCompleted;

@end
