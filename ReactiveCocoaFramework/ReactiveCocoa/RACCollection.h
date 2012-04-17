//
//  RACCollection.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubject;
@class RACSubscribable;


@interface RACCollection : NSObject <NSFastEnumeration, NSCopying>

@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly) RACSubject *objectsAdded;
@property (nonatomic, readonly) RACSubject *objectsRemoved;
@property (nonatomic, readonly) RACSubscribable *countChanged;

+ (RACCollection *)collectionWithObjectsInArray:(NSArray *)array;
+ (RACCollection *)collectionWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;

- (void)addObject:(id)object;
- (void)insertObject:(id)object atIndex:(NSUInteger)index;

- (void)removeObject:(id)object;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)removeAllObjects;

- (id)objectAtIndex:(NSUInteger)index;

- (NSArray *)allObjects;

- (RACCollection *)derivedCollection:(id (^)(id object))selectBlock;

@end
