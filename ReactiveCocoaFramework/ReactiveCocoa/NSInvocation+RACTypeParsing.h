//
//  NSInvocation+RACTypeParsing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSInvocation (RACTypeParsing)

// Sets the argument for the invocation at the given index by unboxing the given
// object based on the type signature of the argument.
//
// Struct and union types are not supported.
//
// object - The object to unbox and set as the argument.
// index  - The index of the argument to set.
- (void)rac_setArgument:(id)object atIndex:(NSUInteger)index;

// Gets the return value from the invocation based on the invocation's method
// signature. The value is then wrapped in the appropriate object type.
//
// Struct and union types are not supported.
//
// Returns the return value of the invocation, wrapped in an object. Voids are
// returned as `RACUnit.defaultUnit`.
- (id)rac_returnValue;

@end
