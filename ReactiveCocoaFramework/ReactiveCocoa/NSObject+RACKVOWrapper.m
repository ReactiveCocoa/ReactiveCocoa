//
//  NSObject+RACKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "RACKVOTrampoline.h"
#import <objc/runtime.h>

@implementation NSObject (RACKVOWrapper)

- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block {
	return [[RACKVOTrampoline alloc] initWithTarget:self observer:observer keyPath:keyPath options:options block:block];
}

@end
