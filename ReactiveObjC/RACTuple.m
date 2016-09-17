//
//  RACTuple.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTuple.h"
#import <ReactiveObjC/EXTKeyPathCoding.h>
#import "RACTupleSequence.h"

@implementation RACTupleNil

+ (RACTupleNil *)tupleNil {
	static dispatch_once_t onceToken;
	static RACTupleNil *tupleNil = nil;
	dispatch_once(&onceToken, ^{
		tupleNil = [[self alloc] init];
	});
	
	return tupleNil;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
	// Always return the singleton.
	return self.class.tupleNil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

@end


@interface RACTuple ()
@property (nonatomic, strong) NSArray *backingArray;
@end


@implementation RACTuple

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.backingArray = [NSArray array];
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> %@", self.class, self, self.allObjects];
}

- (BOOL)isEqual:(RACTuple *)object {
	if (object == self) return YES;
	if (![object isKindOfClass:self.class]) return NO;
	
	return [self.backingArray isEqual:object.backingArray];
}

- (NSUInteger)hash {
	return self.backingArray.hash;
}


#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
	return [self.backingArray countByEnumeratingWithState:state objects:buffer count:len];
}


#pragma mark NSCopying

- (instancetype)copyWithZone:(NSZone *)zone {
	// we're immutable, bitches!
	return self;
}


#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder {
	self = [self init];
	if (self == nil) return nil;
	
	self.backingArray = [coder decodeObjectForKey:@keypath(self.backingArray)];
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	if (self.backingArray != nil) [coder encodeObject:self.backingArray forKey:@keypath(self.backingArray)];
}


#pragma mark API

+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array {
	return [self tupleWithObjectsFromArray:array convertNullsToNils:NO];
}

+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert {
	RACTuple *tuple = [[self alloc] init];
	
	if (convert) {
		NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
		for (id object in array) {
			[newArray addObject:(object == NSNull.null ? RACTupleNil.tupleNil : object)];
		}
		
		tuple.backingArray = newArray;
	} else {
		tuple.backingArray = [array copy];
	}
	
	return tuple;
}

+ (instancetype)tupleWithObjects:(id)object, ... {
	RACTuple *tuple = [[self alloc] init];

	va_list args;
	va_start(args, object);

	NSUInteger count = 0;
	for (id currentObject = object; currentObject != nil; currentObject = va_arg(args, id)) {
		++count;
	}

	va_end(args);

	if (count == 0) {
		tuple.backingArray = @[];
		return tuple;
	}
	
	NSMutableArray *objects = [[NSMutableArray alloc] initWithCapacity:count];
	
	va_start(args, object);
	for (id currentObject = object; currentObject != nil; currentObject = va_arg(args, id)) {
		[objects addObject:currentObject];
	}

	va_end(args);
	
	tuple.backingArray = objects;
	return tuple;
}

- (id)objectAtIndex:(NSUInteger)index {
	if (index >= self.count) return nil;
	
	id object = self.backingArray[index];
	return (object == RACTupleNil.tupleNil ? nil : object);
}

- (NSArray *)allObjects {
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.backingArray.count];
	for (id object in self.backingArray) {
		[newArray addObject:(object == RACTupleNil.tupleNil ? NSNull.null : object)];
	}
	
	return newArray;
}

- (instancetype)tupleByAddingObject:(id)obj {
	NSArray *newArray = [self.backingArray arrayByAddingObject:obj ?: RACTupleNil.tupleNil];
	return [self.class tupleWithObjectsFromArray:newArray];
}

- (NSUInteger)count {
	return self.backingArray.count;
}

- (id)first {
	return self[0];
}

- (id)second {
	return self[1];
}

- (id)third {
	return self[2];
}

- (id)fourth {
	return self[3];
}

- (id)fifth {
	return self[4];
}

- (id)last {
	return self[self.count - 1];
}

@end


@implementation RACTuple (RACSequenceAdditions)

- (RACSequence *)rac_sequence {
	return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

@end

@implementation RACTuple (ObjectSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
	return [self objectAtIndex:idx];
}

@end


@implementation RACTupleUnpackingTrampoline

#pragma mark Lifecycle

+ (instancetype)trampoline {
	static dispatch_once_t onceToken;
	static id trampoline = nil;
	dispatch_once(&onceToken, ^{
		trampoline = [[self alloc] init];
	});
	
	return trampoline;
}

- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables {
	NSCParameterAssert(variables != nil);
	
	[variables enumerateObjectsUsingBlock:^(NSValue *value, NSUInteger index, BOOL *stop) {
		__strong id *ptr = (__strong id *)value.pointerValue;
		*ptr = tuple[index];
	}];
}

@end
