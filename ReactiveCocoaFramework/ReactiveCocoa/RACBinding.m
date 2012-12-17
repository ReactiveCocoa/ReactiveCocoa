//
//  RACBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"

@interface RACKeyPathBindingPoint : RACBindingPoint

@property (atomic, readonly, strong) id target;
@property (atomic, readonly, copy) NSString *keyPath;

- (instancetype)initWithTarget:(id)target keyPath:(NSString *)keyPath;

@end

@interface RACTransformerBindingPoint : RACBindingPoint

@property (atomic, readonly, copy) RACBindingPoint *target;
@property (atomic, readonly, copy) RACTuple *(^transformer)(RACTuple *);

- (instancetype)initWithTarget:(RACBindingPoint *)target transformer:(RACTuple *(^)(RACTuple *))transformer;

@end

@implementation RACBindingPoint

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSDictionary

- (id)objectForKeyedSubscript:(id)key {
	return self;
}

#pragma mark NSMutableDictionary

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
	[self bindWithOtherPoint:obj];
}

#pragma mark API

+ (instancetype)bindingPointFor:(id)target keyPath:(NSString *)keyPath {
	return [[RACKeyPathBindingPoint alloc] initWithTarget:target keyPath:keyPath];
}

- (instancetype)bindingPointByTransformingSignals:(RACTuple *(^)(RACTuple *))signalsTransformer {
	return [[RACTransformerBindingPoint alloc] initWithTarget:self transformer:signalsTransformer];
}

@end

@implementation RACKeyPathBindingPoint

- (instancetype)initWithTarget:(id)target keyPath:(NSString *)keyPath {
	self = [super init];
	if (self == nil || target == nil || keyPath == nil) return nil;
	_target = target;
	_keyPath = [keyPath copy];
	return self;
}

@end

@implementation RACTransformerBindingPoint

- (instancetype)initWithTarget:(RACBindingPoint *)target transformer:(RACTuple *(^)(RACTuple *))transformer {
	self = [super init];
	if (self == nil || target == nil || transformer == nil) return nil;
	_target = [target copy];
	_transformer = [transformer copy];
	return self;
}

@end

@implementation NSObject (RACBinding)

- (RACBindingPoint *)rac_bindingPointForKeyPath:(NSString *)keyPath {
	return [RACBindingPoint bindingPointFor:self keyPath:keyPath];
}

@end
