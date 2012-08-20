//
//  RACBehaviorSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBehaviorSubject.h"

@interface RACBehaviorSubject ()
@property (strong) id currentValue;
@end


@implementation RACBehaviorSubject


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	RACDisposable *disposable = [super subscribe:subscriber];
	[subscriber sendNext:self.currentValue];
	
	return disposable;
}


#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[super sendNext:value];
	
	self.currentValue = value;
}


#pragma mark API

@synthesize currentValue;

+ (instancetype)behaviorSubjectWithDefaultValue:(id)value {
	RACBehaviorSubject *subject = [self subject];
	subject.currentValue = value;
	return subject;
}

@end
