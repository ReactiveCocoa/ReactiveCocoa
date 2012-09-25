//
//  RACSubscriptingAssignmentTrampoline.m
//  iOSDemo
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriptingAssignmentTrampoline.h"

@interface RACSubscriptingAssignmentTrampoline ()
@property (nonatomic, readonly, strong) NSObject *object;
@property (nonatomic, readonly, copy) NSString *keyPath;
@end

@implementation RACSubscriptingAssignmentTrampoline

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark API

+ (instancetype)bouncer {
	static dispatch_once_t onceToken;
	static RACSubscriptingAssignmentTrampoline *bouncer = nil;
	dispatch_once(&onceToken, ^{
		bouncer = [[self alloc] init];
	});

	return bouncer;
}

- (id)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath {
	self = [super init];
	if (self == nil) return nil;

	_object = object;
	_keyPath = [keyPath copy];

	return self;
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
	NSAssert([(id) key isKindOfClass:RACSubscriptingAssignmentTrampoline.class], @"RACSubscriptingAssignmentTrampoline should only be used through the RAC macro.");

	RACSubscriptingAssignmentTrampoline *trampoline = (RACSubscriptingAssignmentTrampoline *) key;
	[trampoline.object rac_deriveProperty:trampoline.keyPath from:obj];
}

@end
