//
//  RACCollection.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCollection.h"
#import "RACSubject.h"
#import "RACSubscribable.h"
#import "RACSubscribable+Operations.h"
#import "RACUnit.h"

@interface RACCollection ()
@property (nonatomic, strong) NSMutableArray *backingArray;
@end


@implementation RACCollection

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	backingArray = [NSMutableArray array];
	objectsAdded = [RACSubject subject];
	objectsRemoved = [RACSubject subject];
	countChanged = [[RACSubscribable merge:[NSArray arrayWithObjects:self.objectsAdded, self.objectsRemoved, nil]] select:^(id x) {
		return [RACUnit defaultUnit];
	}];
	
	return self;
}


#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
	return [self.backingArray countByEnumeratingWithState:state objects:buffer count:len];
}


#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return [[self class] collectionWithObjectsInArray:self.backingArray];
}


#pragma mark API

@synthesize backingArray;
@synthesize objectsAdded;
@synthesize objectsRemoved;
@synthesize countChanged;

+ (RACCollection *)collectionWithObjectsInArray:(NSArray *)array {
	RACCollection *collection = [[self alloc] init];
	for(id object in array) {
		[collection addObject:object];
	}
	return collection;
}

+ (RACCollection *)collectionWithObjects:(id)object, ... {
	RACCollection *collection = [[self alloc] init];
	
	va_list args;
    va_start(args, object);
    for(id currentObject = object; currentObject != nil; currentObject = va_arg(args, id)) {
        [collection addObject:currentObject];
    }
    va_end(args);
	
	return collection;
}

- (NSUInteger)count {
	return self.backingArray.count;
}

- (void)addObject:(id)object {
	[self.backingArray addObject:object];
	[self.objectsAdded sendNext:object];
}

- (void)removeObject:(id)object {
	[self.backingArray removeObject:object];
	[self.objectsRemoved sendNext:object];
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
	[self.backingArray insertObject:object atIndex:index];
	[self.objectsAdded sendNext:object];
}

- (void)removeObjectAtIndex:(NSUInteger)index {
	id object = [self.backingArray objectAtIndex:index];
	[self.backingArray removeObjectAtIndex:index];
	[self.objectsRemoved sendNext:object];
}

- (void)removeAllObjects {
	NSArray *oldObjects = [self.backingArray copy];
	[self.backingArray removeAllObjects];
	for(id object in oldObjects) {
		[self.objectsRemoved sendNext:object];
	}
}

- (id)objectAtIndex:(NSUInteger)index {
	return [self.backingArray objectAtIndex:index];
}

- (NSArray *)allObjects {
	return [self.backingArray copy];
}

- (RACCollection *)derivedCollection:(id (^)(id object))selectBlock {
	NSParameterAssert(selectBlock != NULL);
	
	RACCollection *copiedCollection = [self copy];
	[[self.objectsAdded select:selectBlock] subscribeNext:^(id x) {
		[copiedCollection addObject:x];
	}];
	
	[self.objectsRemoved subscribeNext:^(id x) {
		[copiedCollection removeObject:x];
	}];
	
	return copiedCollection;
}

@end
