//
//  NSInvocation+RACTypeParsing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACTuple;

@interface NSInvocation (RACTypeParsing)

// Sets the argument for the invocation at the given index by unboxing the given
// object based on the type signature of the argument.
//
// This does not support C arrays or unions.
//
// Note that calling this on a char * or const char * argument can cause all
// arguments to be retained.
//
// object - The object to unbox and set as the argument.
// index  - The index of the argument to set.
- (void)rac_setArgument:(id)object atIndex:(NSUInteger)index;

// Gets the argument for the invocation at the given index based on the
// invocation's method signature. The value is then wrapped in the appropriate
// object type.
//
// This does not support C arrays or unions.
//
// index  - The index of the argument to get.
//
// Returns the argument of the invocation, wrapped in an object.
- (id)rac_argumentAtIndex:(NSUInteger)index;

// Arguments tuple for the invocation.
//
// The arguments tuple excludes implicit variables `self` and `_cmd`.
//
// See -rac_argumentAtIndex: and -rac_setArgumentAtIndex: for further
// description of the underlying behavior.
@property (nonatomic, copy) RACTuple *rac_argumentsTuple;

// Gets the return value from the invocation based on the invocation's method
// signature. The value is then wrapped in the appropriate object type.
//
// This does not support C arrays or unions.
//
// Returns the return value of the invocation, wrapped in an object. Voids are
// returned as `RACUnit.defaultUnit`.
- (id)rac_returnValue;

@end
