//
//  RACTuple.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"
#import "metamacros.h"

@class RACSequence;
@class RACSignal;

/// Creates a new tuple with the given values. At least one value must be given.
/// Values can be nil.
#define RACTuplePack(...) \
    RACTuplePack_(__VA_ARGS__)

/// Declares new object variables and unpacks a RACTuple into them.
///
/// This macro should be used on the left side of an assignment, with the
/// tuple on the right side. Nothing else should appear on the same line, and the
/// macro should not be the only statement in a conditional or loop body.
///
/// If the tuple has more values than there are variables listed, the excess
/// values are ignored.
///
/// If the tuple has fewer values than there are variables listed, the excess
/// variables are initialized to nil.
///
/// Examples
///
///   RACTupleUnpack(NSString *string, NSNumber *num) = [RACTuple tupleWithObjects:@"foo", @5, nil];
///   NSLog(@"string: %@", string);
///   NSLog(@"num: %@", num);
///
///   /* The above is equivalent to: */
///   RACTuple *t = [RACTuple tupleWithObjects:@"foo", @5, nil];
///   NSString *string = t[0];
///   NSNumber *num = t[1];
///   NSLog(@"string: %@", string);
///   NSLog(@"num: %@", num);
#define RACTupleUnpack(...) \
        RACTupleUnpack_(__VA_ARGS__)

/// A sentinel object that represents nils in the tuple.
///
/// It should never be necessary to create a tuple nil yourself. Just use
/// +tupleNil.
@interface RACTupleNil : NSObject <NSCopying, NSCoding>

/// A singleton instance.
+ (instancetype)tupleNil;

@end

/// A tuple is an ordered collection of objects. It may contain nils, represented
/// by RACTupleNil.
@interface RACTuple : NSObject <NSCoding, NSCopying, NSFastEnumeration>

/// The number of objects in the tuple, including any nil values.
@property (nonatomic, readonly) NSUInteger count;

/// An array of all the objects in the tuple.
///
/// RACTupleNils are converted to NSNulls in the array.
@property (nonatomic, copy, readonly) NSArray *array;

/// A signal that will send all of the objects in the tuple.
///
/// RACTupleNils will be sent as `nil` values on the signal.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

/// Invokes +tupleWithArray:convertNullsToNils: with `convert` set to NO.
+ (instancetype)tupleWithArray:(NSArray *)array;

/// Creates a new tuple out of the given array.
///
/// convert - Whether to convert `NSNull` objects in the array to `RACTupleNil`
///           values for the tuple. If this is NO, `NSNull`s will be left
///           untouched.
+ (instancetype)tupleWithArray:(NSArray *)array convertNullsToNils:(BOOL)convert;

/// Creates a new tuple with the given objects.
///
/// To include nil objects in the tuple, use `RACTupleNil` in the argument list.
+ (instancetype)tupleWithObjects:(id)object, ... NS_REQUIRES_NIL_TERMINATION;

/// Retrieves the object at the given index.
///
/// Unlike `NSArray` and friends, it's perfectly fine to ask for the object at
/// an index past the end of the tuple. It will simply return nil.
///
/// Returns the object at `index`, or `nil` if the object is a `RACTupleNil` or
/// the index is out of bounds.
- (id)objectAtIndex:(NSUInteger)index;

@end

@interface RACTuple (ObjectSubscripting)

/// Invokes -objectAtIndex: with the given index.
- (id)objectAtIndexedSubscript:(NSUInteger)idx; 

@end

@interface RACTuple (Deprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Use -rac_signal instead");
@property (nonatomic, copy, readonly) NSArray *allObjects RACDeprecated("Renamed to -array");

@property (nonatomic, strong, readonly) id first RACDeprecated("Use subscripting or -objectAtIndex: instead");
@property (nonatomic, strong, readonly) id second RACDeprecated("Use subscripting or -objectAtIndex: instead");
@property (nonatomic, strong, readonly) id third RACDeprecated("Use subscripting or -objectAtIndex: instead");
@property (nonatomic, strong, readonly) id fourth RACDeprecated("Use subscripting or -objectAtIndex: instead");
@property (nonatomic, strong, readonly) id fifth RACDeprecated("Use subscripting or -objectAtIndex: instead");
@property (nonatomic, strong, readonly) id last RACDeprecated("Use subscripting or -objectAtIndex: instead");

- (instancetype)tupleByAddingObject:(id)obj RACDeprecated("Use -array and -arrayByAddingObject: instead");

@end

/// This and everything below is for internal use only.
///
/// See RACTuplePack() and RACTupleUnpack() instead.
#define RACTuplePack_(...) \
    ([RACTuple tupleWithArray:@[ metamacro_foreach(RACTuplePack_object_or_ractuplenil,, __VA_ARGS__) ]])

#define RACTuplePack_object_or_ractuplenil(INDEX, ARG) \
    (ARG) ?: RACTupleNil.tupleNil,

#define RACTupleUnpack_(...) \
    metamacro_foreach(RACTupleUnpack_decl,, __VA_ARGS__) \
    \
    int RACTupleUnpack_state = 0; \
    \
    RACTupleUnpack_after: \
        ; \
        metamacro_foreach(RACTupleUnpack_assign,, __VA_ARGS__) \
        if (RACTupleUnpack_state != 0) RACTupleUnpack_state = 2; \
        \
        while (RACTupleUnpack_state != 2) \
            if (RACTupleUnpack_state == 1) { \
                goto RACTupleUnpack_after; \
            } else \
                for (; RACTupleUnpack_state != 1; RACTupleUnpack_state = 1) \
                    [RACTupleUnpackingTrampoline trampoline][ @[ metamacro_foreach(RACTupleUnpack_value,, __VA_ARGS__) ] ]

#define RACTupleUnpack_state metamacro_concat(RACTupleUnpack_state, __LINE__)
#define RACTupleUnpack_after metamacro_concat(RACTupleUnpack_after, __LINE__)
#define RACTupleUnpack_loop metamacro_concat(RACTupleUnpack_loop, __LINE__)

#define RACTupleUnpack_decl_name(INDEX) \
    metamacro_concat(metamacro_concat(RACTupleUnpack, __LINE__), metamacro_concat(_var, INDEX))

#define RACTupleUnpack_decl(INDEX, ARG) \
    __strong id RACTupleUnpack_decl_name(INDEX);

#define RACTupleUnpack_assign(INDEX, ARG) \
    __strong ARG = RACTupleUnpack_decl_name(INDEX);

#define RACTupleUnpack_value(INDEX, ARG) \
    [NSValue valueWithPointer:&RACTupleUnpack_decl_name(INDEX)],

@interface RACTupleUnpackingTrampoline : NSObject

+ (instancetype)trampoline;
- (void)setObject:(RACTuple *)tuple forKeyedSubscript:(NSArray *)variables;

@end
