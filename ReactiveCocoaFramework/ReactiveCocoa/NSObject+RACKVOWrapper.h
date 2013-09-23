//
//  NSObject+RACKVOWrapper.h
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>


/// RAC-specific KVO change dictionary key: Will be @YES if the change was caused
/// by the value at the key path or an intermediate value deallocating, @NO
/// otherwise.
extern NSString * const RACKeyValueChangeCausedByDeallocationKey;

/// RAC-specific KVO change dictionary key: Will be @YES if the change only
/// affected the value of the last key path component leaving the values of the
/// intermediate key path components unaltered, @NO otherwise.
extern NSString * const RACKeyValueChangeAffectedOnlyLastComponentKey;

@class RACDisposable, RACKVOTrampoline;

@interface NSObject (RACKVOWrapper)

/// Adds the given block as the callbacks for when the key path changes.
///
/// Unlike direct KVO observation, this handles deallocation of `weak` properties
/// by generating an appropriate notification. This will only occur if there is
/// an `@property` declaration visible in the observed class, with the `weak`
/// memory management attribute.
///
/// The observation does not need to be explicitly removed. It will be removed
/// when the observer or the receiver deallocate.
///
/// keyPath  - The key path to observe. Must not be nil.
/// options  - The KVO observation options.
/// observer - The object that requested the observation. May be nil.
/// block    - The block called when the value at the key path changes. It is
///            passed the current value of the key path and the extended KVO
///            change dictionary including RAC-specific keys and values. Must not
///            be nil.
///
/// Returns a disposable that can be used to stop the observation.
- (RACDisposable *)rac_observeKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer block:(void (^)(id value, NSDictionary *change))block;

@end

typedef void (^RACKVOBlock)(id target, id observer, NSDictionary *change);

@interface NSObject (RACKVOWrapperDeprecated)

- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block __attribute((deprecated("Use rac_observeKeyPath:options:observer:block: instead.")));

@end
