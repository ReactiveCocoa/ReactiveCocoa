//
//  RACCollection.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;

@interface RACCollection : NSObject <NSFastEnumeration, NSCopying>

// The number of objects in the collection.
@property (nonatomic, readonly) NSUInteger count;

// Sends each object after it has been added. It never completes or errors.
@property (nonatomic, readonly) RACSignal *objectsAdded;

// Sends each object after it has been removed. It never completes or errors.
@property (nonatomic, readonly) RACSignal *objectsRemoved;

// Sends a -[RACUnit defaultUnit] whenever the count changes. It never completes
// or errors.
@property (nonatomic, readonly) RACSignal *countChanged;

// Controls whether change notifications are sent. Defaults to YES.
@property (nonatomic, assign) BOOL changeNotificationsEnabled;

+ (instancetype)collectionWithObjectsInArray:(NSArray *)array;
+ (instancetype)collectionWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;

- (void)addObject:(id)object;
- (void)addObjectsFromArray:(NSArray *)otherArray;
- (void)insertObject:(id)object atIndex:(NSUInteger)index;

- (void)removeObject:(id)object;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)removeAllObjects;

- (id)objectAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfObject:(id)object;

- (NSArray *)allObjects;

// Performs the given block with change notifications disabled.
- (void)withChangeNotificationsSuppressed:(void (^)(void))block;

@end
