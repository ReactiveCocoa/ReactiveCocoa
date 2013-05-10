//
//  RACSubscriptingAssignmentTrampoline.m
//  iOSDemo
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscriptingAssignmentTrampoline.h"

@interface RACSubscriptingAssignmentObjectKeyPathPair ()
@property (nonatomic, readonly, strong) NSObject *object;
@property (nonatomic, readonly, copy) NSString *keyPath;
@end

@implementation RACSubscriptingAssignmentObjectKeyPathPair

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark API

- (id)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath {
	self = [super init];
	if (self == nil) return nil;

	_object = object;
	_keyPath = [keyPath copy];

	return self;
}

@end

@implementation RACSubscriptingAssignmentTrampoline

#pragma mark API

+ (instancetype)trampoline {
	static dispatch_once_t onceToken;
	static RACSubscriptingAssignmentTrampoline *trampoline = nil;
	dispatch_once(&onceToken, ^{
		trampoline = [[self alloc] init];
	});

	return trampoline;
}

- (void)setObject:(RACSignal *)signal forKeyedSubscript:(RACSubscriptingAssignmentObjectKeyPathPair *)pair {
	NSCParameterAssert([pair isKindOfClass:RACSubscriptingAssignmentObjectKeyPathPair.class]);

	[pair.object rac_deriveProperty:pair.keyPath from:signal];
}

@end
