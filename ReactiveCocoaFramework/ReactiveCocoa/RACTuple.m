//
//  RACTuple.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTuple.h"


@implementation RACTupleNil

+ (RACTupleNil *)tupleNil {
	static dispatch_once_t onceToken;
	static RACTupleNil *tupleNil = nil;
	dispatch_once(&onceToken, ^{
		tupleNil = [[self alloc] init];
	});
	
	return tupleNil;
}

@end


@interface RACTuple ()
@property (nonatomic, strong) NSArray *backingArray;
@end


@implementation RACTuple

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.backingArray = [NSArray array];
	
	return self;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p> %@", NSStringFromClass([self class]), self, [self allObjects]];
}


#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len {
	return [self.backingArray countByEnumeratingWithState:state objects:buffer count:len];
}


#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	// we're immutable, bitches!
	return self;
}


#pragma mark API

@synthesize backingArray;

+ (id)tupleWithObjectsFromArray:(NSArray *)array {
	return [self tupleWithObjectsFromArray:array convertNullsToNils:NO];
}

+ (id)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert {
	RACTuple *tuple = [[self alloc] init];
	
	if(convert) {
		NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:array.count];
		for(id object in array) {
			[newArray addObject:[object isKindOfClass:[NSNull class]] ? [RACTupleNil tupleNil] : object];
		}
		
		tuple.backingArray = [newArray copy];
	} else {
		tuple.backingArray = [array copy];
	}
	
	return tuple;
}

+ (id)tupleWithObjects:(id)object, ... {
	RACTuple *tuple = [[self alloc] init];
	
	NSMutableArray *objects = [NSMutableArray array];
	
	va_list args;
    va_start(args, object);
    for(id currentObject = object; currentObject != nil; currentObject = va_arg(args, id)) {
        [objects addObject:currentObject];
    }
    va_end(args);
	
	tuple.backingArray = [objects copy];
	
	return tuple;
}

- (id)objectAtIndex:(NSUInteger)index {
	id object = [self.backingArray objectAtIndex:index];
	return [object isKindOfClass:[RACTupleNil class]] ? nil : object;
}

- (NSArray *)allObjects {
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.backingArray.count];
	for(id object in self.backingArray) {
		[newArray addObject:[object isKindOfClass:[RACTupleNil class]] ? [NSNull null] : object];
	}
	
	return newArray;
}

- (NSUInteger)count {
	return self.backingArray.count;
}

@end
