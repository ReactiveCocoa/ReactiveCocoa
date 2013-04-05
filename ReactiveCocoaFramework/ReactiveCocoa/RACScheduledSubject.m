//
//  RACScheduledSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACScheduledSubject.h"
#import "RACScheduler.h"

@interface RACScheduledSubject ()

@property (nonatomic, readonly, strong) RACScheduler *scheduler;

@end

@implementation RACScheduledSubject

#pragma mark Lifecycle

+ (instancetype)subjectWithScheduler:(RACScheduler *)scheduler {
	return [[self alloc] initWithScheduler:scheduler];
}

- (id)initWithScheduler:(RACScheduler *)scheduler {
	NSParameterAssert(scheduler != nil);

	self = [super init];
	if (self == nil) return nil;

	_scheduler = scheduler;

	return self;
}

#pragma mark RACSubject

- (void)sendNext:(id)value {
	[self.scheduler schedule:^{
		[super sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self.scheduler schedule:^{
		[super sendError:error];
	}];
}

- (void)sendCompleted {
	[self.scheduler schedule:^{
		[super sendCompleted];
	}];
}

@end
