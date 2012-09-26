//
//  RACSubscriptingAssignmentTrampoline.h
//  iOSDemo
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACPropertySubscribing.h"

// Lets you assign a keypath / property to a subscribable. The value of the
// keypath or property is then kept up-to-date with the latest value from the
// subscribable.
//
// If given just one argument, it's assumed to be a keypath or property on self.
// If given two, the first argument is the object to which the keypath is
// relative and the second is the keypath.
//
// Examples:
//
//  RAC(self.blah) = someSubscribable;
//  RAC(otherObject, blah) = someSubscribable;
#define RAC(...) metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(_RAC_OBJ(self, __VA_ARGS__))(_RAC_OBJ(__VA_ARGS__))

// Do not use this directly. Use the RAC macro above.
#define _RAC_OBJ(obj, keypath) [RACSubscriptingAssignmentTrampoline trampoline][ [[RACSubscriptingAssignmentObjectKeyPathPair alloc] initWithObject:obj keyPath:RAC_KEYPATH(obj, keypath)] ]

@interface RACSubscriptingAssignmentObjectKeyPathPair : NSObject <NSCopying>

- (id)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath;

@end

@interface RACSubscriptingAssignmentTrampoline : NSObject

+ (instancetype)trampoline;

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

@end
