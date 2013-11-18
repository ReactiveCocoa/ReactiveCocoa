//
//  RACBehaviorSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#define WE_PROMISE_TO_MIGRATE_TO_REACTIVECOCOA_3_0

#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACLiveSubscriber.h"
#import "RACScheduler+Private.h"
#import "RACSignal+Private.h"

@interface RACBehaviorSubject ()

// This property should only be used while synchronized on self.
@property (nonatomic, strong) id currentValue;

@end

@implementation RACBehaviorSubject

#pragma mark Lifecycle

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value {
	RACBehaviorSubject *subject = [self subject];
	subject.currentValue = value;
	return subject;
}

#pragma mark RACSignal

- (void)attachSubscriber:(RACLiveSubscriber *)subscriber {
	[super attachSubscriber:subscriber];

	@synchronized (self) {
		[subscriber sendNext:self.currentValue];
	}
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	@synchronized (self) {
		self.currentValue = value;
		[super sendNext:value];
	}
}

@end
