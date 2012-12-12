//
//  RACTuple.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "metamacros.h"

// Unpacks a tuple into variables.
#define RACTupleUnpack(...) \
    [RACTupleUnpackingTrampoline trampoline][ @[ metamacro_foreach(RACTupleUnpack_iter,, __VA_ARGS__) ] ]

#define RACTupleUnpack_iter(INDEX, ARG) \
    [NSValue valueWithPointer:&ARG],

// A sentinel object that represents nils in the tuple.
//
// It should never be necessary to create a tuple nil yourself. Just use +tupleNil.
@interface RACTupleNil : NSObject <NSCopying, NSCoding>
// A singleton instance.
+ (RACTupleNil *)tupleNil;
@end


// A tuple is an ordered collection of objects. It may contain nils, represented
// by RACTupleNil.
@interface RACTuple : NSObject <NSCoding, NSCopying, NSFastEnumeration>

@property (nonatomic, readonly) NSUInteger count;

// These properties all return the object at that index or nil if the number of 
// objects is less than the index.
@property (nonatomic, readonly) id first;
@property (nonatomic, readonly) id second;
@property (nonatomic, readonly) id third;
@property (nonatomic, readonly) id fourth;
@property (nonatomic, readonly) id fifth;
@property (nonatomic, readonly) id last;

// Creates a new tuple out of the array. Does not convert nulls to nils.
+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array;

// Creates a new tuple out of the array. If `convert` is YES, it also converts
// every NSNull to RACTupleNil.
+ (instancetype)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert;

// Creates a new tuple with the given objects. Use RACTupleNil to represent nils.
+ (instancetype)tupleWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;

// Returns the object at `index` or nil if the object is a RACTupleNil. Unlike
// NSArray and friends, it's perfectly fine to ask for the object at an index
// past the tuple's count - 1. It will simply return nil.
- (id)objectAtIndex:(NSUInteger)index;

// Returns an array of all the objects. RACTupleNils are converted to NSNulls.
- (NSArray *)allObjects;

@end


@interface RACTuple (ObjectSubscripting)
// Returns the object at that index or nil if the number of objects is less
// than the index.
- (id)objectAtIndexedSubscript:(NSUInteger)idx; 
@end


@interface RACTupleUnpackingTrampoline : NSObject

+ (instancetype)trampoline;
- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables;

@end
