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
// object based on the argument type signature.
//
// argType - The type signature of the argument at that index. Cannot be NULL.
// index   - The index of the argument to set.
// object  - The object to unbox and set as the argument.
- (void)rac_setArgumentForType:(const char *)argType atIndex:(NSInteger)index withObject:(id)object;

// Gets the return value from the invocation based on the given type signature.
// The value is then wrapped in the appropriate object type.
//
// typeSignature - The type signature of the return value. Cannot be NULL.
//
// Returns the return value of the invocation, wrapped in an object. Voids are
// returned as `RACUnit.defaultUnit`.
- (id)rac_returnValueWithTypeSignature:(const char *)typeSignature;

@end
