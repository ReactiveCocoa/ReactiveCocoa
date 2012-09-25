//
//  RACSubscriptingAssignmentTrampoline.h
//  iOSDemo
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACPropertySubscribing.h"

#define RAC_OBJ(obj, keypath) [RACSubscriptingAssignmentTrampoline bouncer][ [[RACSubscriptingAssignmentTrampoline alloc] initWithObject:obj keyPath:RAC_KEYPATH(obj, keypath)] ]
#define RAC(keypath) RAC_OBJ(self, keypath)

@interface RACSubscriptingAssignmentTrampoline : NSObject <NSCopying>

+ (instancetype)bouncer;

- (id)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath;

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

@end
