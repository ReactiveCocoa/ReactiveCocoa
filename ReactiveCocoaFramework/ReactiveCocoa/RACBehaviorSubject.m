//
//  RACBehaviorSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACBehaviorSubject.h"

@interface RACBehaviorSubject ()
@property (nonatomic, strong) id currentValue;
@end


@implementation RACBehaviorSubject


#pragma mark RACObservable

- (id<RACObserver>)subscribe:(id<RACObserver>)observer {
	id<RACObserver> actualObserver = [super subscribe:observer];
	[actualObserver sendNext:self.currentValue];
	
	return actualObserver;
}


#pragma mark RACObserver

- (void)sendNext:(id)value {
	[super sendNext:value];
	
	self.currentValue = value;
}


#pragma mark API

@synthesize currentValue;

+ (id)behaviorSubjectWithDefaultValue:(id)value {
	RACBehaviorSubject *subject = [self subject];
	subject.currentValue = value;
	return subject;
}

@end
