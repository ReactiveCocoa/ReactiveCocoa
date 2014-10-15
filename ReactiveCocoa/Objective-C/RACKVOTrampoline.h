//
//  RACKVOTrampoline.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 1/15/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+RACKVOWrapper.h"
#import "RACDisposable.h"

// A private trampoline object that represents a KVO observation.
//
// Disposing of the trampoline will stop observation.
@interface RACKVOTrampoline : RACDisposable

// Initializes the receiver with the given parameters.
//
// target   - The object whose key path should be observed. Cannot be nil.
// observer - The object that gets notified when the value at the key path
//            changes. Can be nil.
// keyPath  - The key path on `target` to observe. Cannot be nil.
// options  - Any key value observing options to use in the observation.
// block    - The block to call when the value at the observed key path changes.
//            Cannot be nil.
//
// Returns the initialized object.
- (id)initWithTarget:(NSObject *)target observer:(NSObject *)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block;

@end
