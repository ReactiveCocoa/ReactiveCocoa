//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSubject.h"
#import "RACSequence+Private.h"


@implementation RACSubject


#pragma mark API

- (void)sendNext:(id)value {
	[self sendNextToAllObservers:value];
}

- (void)sendCompleted {
	[self sendCompletedToAllObservers];
}

- (void)sendError:(NSError *)error {
	[self sendErrorToAllObservers:error];
}

@end
