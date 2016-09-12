//
//  RACKVOProxy.h
//  ReactiveObjC
//
//  Created by Richard Speyer on 4/10/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/// A singleton that can act as a proxy between a KVO observation and a RAC
/// subscriber, in order to protect against KVO lifetime issues.
@interface RACKVOProxy : NSObject

/// Returns the singleton KVO proxy object.
+ (instancetype)sharedProxy;

/// Registers an observer with the proxy, such that when the proxy receives a
/// KVO change with the given context, it forwards it to the observer.
///
/// observer - True observer of the KVO change. Must not be nil.
/// context  - Arbitrary context object used to differentiate multiple
///            observations of the same keypath. Must be unique, cannot be nil.
- (void)addObserver:(__weak NSObject *)observer forContext:(void *)context;

/// Removes an observer from the proxy. Parameters must match those passed to
/// addObserver:forContext:.
///
/// observer - True observer of the KVO change. Must not be nil.
/// context  - Arbitrary context object used to differentiate multiple
///            observations of the same keypath. Must be unique, cannot be nil.
- (void)removeObserver:(NSObject *)observer forContext:(void *)context;

@end
