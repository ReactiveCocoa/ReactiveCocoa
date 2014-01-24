//
//  RACMoveMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACMoveMutation.h"

@implementation RACMoveMutation

#pragma mark Lifecycle

- (instancetype)initWithFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
	NSCParameterAssert(fromIndex != NSNotFound);
	NSCParameterAssert(toIndex != NSNotFound);

	self = [super init];
	if (self == nil) return nil;

	_fromIndex = fromIndex;
	_toIndex = toIndex;

	return self;
}

#pragma mark RACCollectionMutation

- (instancetype)map:(id (^)(id object))block {
	return self;
}

- (void)mutateCollection:(id<RACCollection>)collection {
	// A move doesn't make any sense upon an unordered collection, so consider
	// it a no-op.
}

#pragma mark RACOrderedCollectionMutation

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_moveObjectAtIndex:self.fromIndex toIndex:self.toIndex];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ fromIndex = %lu, toIndex = %lu }", self.class, self, (unsigned long)self.fromIndex, (unsigned long)self.toIndex];
}

- (NSUInteger)hash {
	return self.fromIndex ^ self.toIndex;
}

- (BOOL)isEqual:(RACMoveMutation *)mutation {
	if (self == mutation) return YES;
	if (![mutation isKindOfClass:RACMoveMutation.class]) return NO;

	return self.fromIndex == mutation.fromIndex && self.toIndex == mutation.toIndex;
}

@end
