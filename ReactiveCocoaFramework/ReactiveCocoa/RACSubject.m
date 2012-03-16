//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubject.h"
#import "RACObservable+Private.h"

@interface RACSubject ()

@end


@implementation RACSubject


#pragma mark RACObserver

- (void)sendNext:(id)value {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendError:error];
		
		[self unsubscribe:observer];
	}];
}

- (void)sendCompleted {
	[self performBlockOnAllSubscribers:^(id<RACObserver> observer) {
		[observer sendCompleted];
		
		[self unsubscribe:observer];
	}];
}


#pragma mark API

+ (id)subject {
	return [[self alloc] init];
}

@end
