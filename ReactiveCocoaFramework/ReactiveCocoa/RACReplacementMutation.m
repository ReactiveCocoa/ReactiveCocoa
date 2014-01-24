//
//  RACReplacementMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACReplacementMutation.h"

#import "NSArray+RACSupport.h"
#import "RACSignal+Operations.h"

@implementation RACReplacementMutation

#pragma mark Lifecycle

- (instancetype)initWithRemovedObjects:(NSArray *)removedObjects addedObjects:(NSArray *)addedObjects indexes:(NSIndexSet *)indexes {
	NSCParameterAssert(removedObjects != nil);
	NSCParameterAssert(addedObjects != nil);
	NSCParameterAssert(indexes != nil);
	NSCParameterAssert(removedObjects.count == indexes.count);
	NSCParameterAssert(addedObjects.count == indexes.count);

	self = [super init];
	if (self == nil) return nil;

	_removedObjects = [removedObjects copy];
	_addedObjects = [addedObjects copy];
	_indexes = [indexes copy];

	return self;
}

#pragma mark RACCollectionMutation

- (instancetype)map:(id (^)(id object))block {
	NSArray *newRemoved = [[self.removedObjects.rac_signal map:block] array];
	NSArray *newAdded = [[self.addedObjects.rac_signal map:block] array];

	return [[self.class alloc] initWithRemovedObjects:newRemoved addedObjects:newAdded indexes:self.indexes];
}

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_removeObjects:self.removedObjects];
	[collection rac_addObjects:self.addedObjects];
}

#pragma mark RACOrderedCollectionMutation

- (void)mutateOrderedCollection:(id<RACOrderedCollection>)collection {
	[collection rac_replaceObjectsAtIndexes:self.indexes withObjects:self.addedObjects];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ indexes = %@, removedObjects = %@, addedObjects = %@ }", self.class, self, self.indexes, self.removedObjects, self.addedObjects];
}

- (NSUInteger)hash {
	return self.removedObjects.hash ^ self.addedObjects.hash ^ self.indexes.hash;
}

- (BOOL)isEqual:(RACReplacementMutation *)mutation {
	if (self == mutation) return YES;
	if (![mutation isKindOfClass:RACReplacementMutation.class]) return NO;

	return [self.removedObjects isEqual:mutation.removedObjects] && [self.addedObjects isEqual:mutation.addedObjects] && [self.indexes isEqual:mutation.indexes];
}

@end
