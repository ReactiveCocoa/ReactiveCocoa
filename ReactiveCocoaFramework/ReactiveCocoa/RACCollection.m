//
//  RACCollection.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/16/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCollection.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACUnit.h"

@interface RACCollection () {
	// We explicitly declare these because otherwise the implicit declaration
	// would make them RACSignals instead of RACSubjects.
	RACSubject *objectsAdded;
	RACSubject *objectsRemoved;
}

@property (nonatomic, strong) NSMutableArray *backingArray;
@property (nonatomic, assign) NSInteger suppressChangeNotificationsCount;
@end


@implementation RACCollection

- (instancetype)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.changeNotificationsEnabled = YES;
	self.suppressChangeNotificationsCount = 0;
	
	self.backingArray = [NSMutableArray array];
	objectsAdded = [RACSubject subject];
	objectsRemoved = [RACSubject subject];
	countChanged = [[RACSignal
		merge:[NSArray arrayWithObjects:self.objectsAdded, self.objectsRemoved, nil]]
		map:^(id _) {
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
	RACCollection *copied = [[self class] collectionWithObjectsInArray:self.backingArray];
	return copied;
}


#pragma mark API

@synthesize backingArray;
@synthesize objectsAdded;
@synthesize objectsRemoved;
@synthesize countChanged;
@synthesize suppressChangeNotificationsCount;
@synthesize changeNotificationsEnabled;

+ (instancetype)collectionWithObjectsInArray:(NSArray *)array {
	RACCollection *collection = [[self alloc] init];
	for(id object in array) {
		[collection addObject:object];
	}
	return collection;
}

+ (instancetype)collectionWithObjects:(id)object, ... {
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
	[self addObjectsFromArray:[NSArray arrayWithObject:object]];
}

- (void)addObjectsFromArray:(NSArray *)otherArray {
	[self.backingArray addObjectsFromArray:otherArray];
	
	if([self changeNotificationsEnabled]) {
		for(id object in otherArray) {
			[objectsAdded sendNext:object];
		}
	}
}

- (void)removeObject:(id)object {
	[self removeObjectAtIndex:[self indexOfObject:object]];
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
	[self.backingArray insertObject:object atIndex:index];
	
	if([self changeNotificationsEnabled]) {
		[objectsAdded sendNext:object];
	}
}

- (void)removeObjectAtIndex:(NSUInteger)index {
	id object = [self.backingArray objectAtIndex:index];
	[self.backingArray removeObjectAtIndex:index];
	
	if([self changeNotificationsEnabled]) {
		[objectsRemoved sendNext:object];
	}
}

- (void)removeAllObjects {
	NSArray *oldObjects = [self.backingArray copy];
	[self.backingArray removeAllObjects];
	
	if([self changeNotificationsEnabled]) {
		for(id object in oldObjects) {
			[objectsRemoved sendNext:object];
		}
	}
}

- (id)objectAtIndex:(NSUInteger)index {
	return [self.backingArray objectAtIndex:index];
}

- (NSUInteger)indexOfObject:(id)object {
	return [self.backingArray indexOfObject:object];
}

- (NSArray *)allObjects {
	return [self.backingArray copy];
}

- (void)withChangeNotificationsSuppressed:(void (^)(void))block {
	NSParameterAssert(block != NULL);
	
	self.suppressChangeNotificationsCount++;
	
	block();
	
	self.suppressChangeNotificationsCount--;
}

- (BOOL)changeNotificationsEnabled {
	return changeNotificationsEnabled && self.suppressChangeNotificationsCount == 0;
}

@end
