//
//  RACTuple.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


// A sentinel object that represents nils in the tuple.
//
// It should never be necessary to create a tuple nil yourself. Just use +tupleNil.
@interface RACTupleNil : NSObject
// A singleton instance.
+ (RACTupleNil *)tupleNil;
@end


// A tuple is an ordered collection of objects. It may contain nils, represented
// by RACTupleNil.
@interface RACTuple : NSObject <NSCopying, NSFastEnumeration>

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
+ (id)tupleWithObjectsFromArray:(NSArray *)array;

// Creates a new tuple out of the array. If `convert` is YES, it also converts
// every NSNull to RACTupleNil.
+ (id)tupleWithObjectsFromArray:(NSArray *)array convertNullsToNils:(BOOL)convert;

// Creates a new tuple with the given objects. Use RACTupleNil to represent nils.
+ (id)tupleWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;

// Returns the object at `index` or nil if the object is a RACTupleNil.
- (id)objectAtIndex:(NSUInteger)index;

// Returns an array of all the objects. RACTupleNils are converted to NSNulls.
- (NSArray *)allObjects;

@end
