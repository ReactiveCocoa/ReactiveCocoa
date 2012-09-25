//
//  RACSubscriptingAssignmentTrampoline.h
//  iOSDemo
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACPropertySubscribing.h"

#define RAC_OBJ(obj, keypath) [RACSubscriptingAssignmentTrampoline trampoline][ [[RACSubscriptingAssignmentObjectKeyPathPair alloc] initWithObject:obj keyPath:RAC_KEYPATH(obj, keypath)] ]
#define RAC(keypath) RAC_OBJ(self, keypath)

@interface RACSubscriptingAssignmentObjectKeyPathPair : NSObject <NSCopying>

- (id)initWithObject:(NSObject *)object keyPath:(NSString *)keyPath;

@end

@interface RACSubscriptingAssignmentTrampoline : NSObject

+ (instancetype)trampoline;

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key;

@end
