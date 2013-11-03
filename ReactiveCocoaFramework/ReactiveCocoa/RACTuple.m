//
//  RACTuple.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTuple.h"
#import "EXTKeyPathCoding.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"
#import "RACTupleSequence.h"

@implementation RACTupleNil

+ (instancetype)tupleNil {
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

#pragma mark Properties

- (NSArray *)allObjects {
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.backingArray.count];
	for (id object in self.backingArray) {
		[newArray addObject:(object == RACTupleNil.tupleNil ? NSNull.null : object)];
	}
	
	return newArray;
}

- (RACSignal *)rac_signal {
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		for (id object in self.backingArray) {
			[subscriber sendNext:(object == RACTupleNil.tupleNil ? nil : object)];

			if (subscriber.disposable.disposed) return;
		}

		[subscriber sendCompleted];
	}] setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

- (NSUInteger)count {
	return self.backingArray.count;
}

- (id)first {
	return [self objectAtIndex:0];
}

- (id)second {
	return [self objectAtIndex:1];
}

- (id)third {
	return [self objectAtIndex:2];
}

- (id)fourth {
	return [self objectAtIndex:3];
}

- (id)fifth {
	return [self objectAtIndex:4];
}

- (id)last {
	return [self objectAtIndex:self.count - 1];
}

#pragma mark Lifecycle

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

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
	
	self.backingArray = [NSArray array];
	
	return self;
}

#pragma mark NSObject

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

#pragma mark Indexing

- (id)objectAtIndex:(NSUInteger)index {
	if (index >= self.count) return nil;
	
	id object = [self.backingArray objectAtIndex:index];
	return (object == RACTupleNil.tupleNil ? nil : object);
}

#pragma mark Transformations

- (instancetype)tupleByAddingObject:(id)obj {
	NSArray *newArray = [self.backingArray arrayByAddingObject:obj ?: RACTupleNil.tupleNil];
	return [self.class tupleWithObjectsFromArray:newArray convertNullsToNils:NO];
}

@end

@implementation RACTuple (ObjectSubscripting)

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
	return [self objectAtIndex:idx];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation RACTuple (Deprecated)

- (RACSequence *)rac_sequence {
	return [RACTupleSequence sequenceWithTupleBackingArray:self.backingArray offset:0];
}

@end

#pragma clang diagnostic pop

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
