//
//  NSArray+RACExtensions.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSArray (RACExtensions)

// Returns a new array by calling `block` for each of the objects in the array.
// `block` should never return nil.
- (NSArray *)rac_select:(id (^)(id object))block;

// Returns a new array by adding only objects for which `block` returns YES.
- (NSArray *)rac_where:(BOOL (^)(id object))block;

// Returns YES if `block` returns YES for any object in the array.
- (BOOL)rac_any:(BOOL (^)(id object))block;

@end
