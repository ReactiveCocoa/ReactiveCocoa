//
//  RACSubscriptingAssignmentTrampoline.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriptingAssignmentTrampoline.h"
#import "RACSignal+Operations.h"

@interface RACSubscriptingAssignmentTrampoline ()

// The object to bind to.
@property (nonatomic, strong, readonly) id target;

// A value to use when `nil` is sent on the bound signal.
@property (nonatomic, strong, readonly) id nilValue;

@end

@implementation RACSubscriptingAssignmentTrampoline

- (id)initWithTarget:(id)target nilValue:(id)nilValue {
	// This is often a programmer error, but this prevents crashes if the target
	// object has unexpectedly deallocated.
	if (target == nil) return nil;

	self = [super init];
	if (self == nil) return nil;

	_target = target;
	_nilValue = nilValue;

	return self;
}

- (void)setObject:(RACSignal *)signal forKeyedSubscript:(NSString *)keyPath {
	[signal setKeyPath:keyPath onObject:self.target nilValue:self.nilValue];
}

@end
