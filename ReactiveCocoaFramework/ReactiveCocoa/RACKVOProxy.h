//
//  RACKVOProxy.h
//  ReactiveCocoa
//
//  Created by Richard Speyer on 4/10/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

// A private singleton proxy object known only to RACKVOTrampoline
// The purpose of this class is to act as a proxy between a KVO-observation
// and the RAC subscriber in order to protect against various crashes
// that can occur when observation is occuring on a different thread
// than the value is being changed
//
// When someone creates a RACObserve, RACKVOTrampoline will
// pass RACKVOProxy.instance as the observer to KVO rather than itself,
// and then will register themselves with the proxy

@interface RACKVOProxy : NSObject
+ (RACKVOProxy *)instance;

// Registers an observer (RACKVOTrampoline) with the proxy, such that
// when the proxy receives a KVO change with the given context, it forwards
// it to the observer
//
// observer - True observer of the KVO change
// context  - Arbitrary context object used to differentiate multiple
//            observations of the same keypath.
//            Must be unique; cannot be nil
- (void)addObserver:(NSObject *)observer forContext:(void *)context;

// Remove an existing observer (RACKVOTrampoline) from the proxy. This
// is done when the trampoline is being disposed. Parameters must
// match those passed to addObserver:forContext:
//
// observer - True observer of the KVO change
// context  - Arbitrary context object used to differentiate multiple
//            observations of the same keypath.
//            Must be unique; cannot be nil
- (void)removeObserver:(NSObject *)observer forContext:(void *)context;
@end
