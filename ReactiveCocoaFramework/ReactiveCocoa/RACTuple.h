//
//  RACTuple.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RACTupleNil : NSObject
+ (RACTupleNil *)tupleNil;
@end


// A tuple is an ordered collection of objects. It may contain nils, represented by RACTupleNil.
@interface RACTuple : NSObject <NSCopying, NSFastEnumeration>

@property (nonatomic, readonly) NSUInteger count;

+ (id)tupleWithObjectsFromArray:(NSArray *)array;
+ (id)tupleWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;

// Returns the object at `index` or nil if the object is a RACTupleNil.
- (id)objectAtIndex:(NSUInteger)index;

- (NSArray *)allObjects;

@end
