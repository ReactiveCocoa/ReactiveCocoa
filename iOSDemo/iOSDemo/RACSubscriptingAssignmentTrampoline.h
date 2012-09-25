//
//  RACSubscriptingAssignmentTrampoline.h
//  iOSDemo
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RAC(keypath) [RACSubscriptingAssignmentTrampoline bouncer][ [[RACSubscriptingAssignmentTrampoline alloc] initWithObject:self keyPath:RAC_KEYPATH_SELF(keypath)] ]

#define RAC_OBJ(obj, keyPath) [RACSubscriptingAssignmentTrampoline bouncer][ [[RACSubscriptingAssignmentTrampoline alloc] initWithObject:obj keyPath:RAC_KEYPATH_SELF(keypath)] ]

@interface RACSubscriptingAssignmentTrampoline : NSObject <NSCopying>

+ (instancetype)bouncer;

- (id)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath;

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

@end
