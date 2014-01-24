//
//  RACMinusMutation.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-26.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACMinusMutation.h"

#import "NSArray+RACSupport.h"
#import "RACSignal+Operations.h"

@implementation RACMinusMutation

#pragma mark Lifecycle

- (instancetype)initWithObjects:(NSArray *)objects {
	NSCParameterAssert(objects != nil);

	self = [super init];
	if (self == nil) return nil;

	_removedObjects = [objects copy];

	return self;
}

#pragma mark RACCollectionMutation

- (instancetype)map:(id (^)(id object))block {
	NSArray *newObjects = [[self.removedObjects.rac_signal map:block] array];
	return [(RACMinusMutation *)[self.class alloc] initWithObjects:newObjects];
}

#pragma mark RACCollectionMutation

- (void)mutateCollection:(id<RACCollection>)collection {
	[collection rac_removeObjects:self.removedObjects];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ removedObjects = %@ }", self.class, self, self.removedObjects];
}

- (NSUInteger)hash {
	return self.removedObjects.hash;
}

- (BOOL)isEqual:(RACMinusMutation *)mutation {
	if (self == mutation) return YES;
	if (![mutation isKindOfClass:RACMinusMutation.class]) return NO;

	return [self.removedObjects isEqual:mutation.removedObjects];
}

@end
