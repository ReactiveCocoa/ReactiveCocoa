//
//  NSObject+RACKVOWrapper.h
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>

// Additional KVO change dictionary keys.
//
// RACKeyValueChangeDeallocation      - Will be @YES if the change was caused by
//                                      the value at the key path or an
//                                      intermediate value deallocating.
// RACKeyValueChangeLastPathComponent - Will be @YES if the change only affected
//                                      the value of the last key path component.
extern NSString * const RACKeyValueChangeCausedByDeallocationKey;
extern NSString * const RACKeyValueChangeAffectedOnlyLastComponentKey;

@class RACDisposable, RACKVOTrampoline;

@interface NSObject (RACKVOWrapper)

// Adds the given block as the callbacks for when the key path changes. Unlike
// direct KVO observation this handles deallocation of intermediate objects by
// generating an appropriate notification.
//
// The observation does not need to be explicitly removed. It will be removed
// when the observer or the receiver deallocate.
//
// keyPath  - The key path to observe.
// options  - The KVO observation options.
// observer - The object that requested the observation.
// block    - The block called when the value at the key path changes. It is
//            passed the current value of the key path and the extended KVO
//            change dictionary including RAC-specific keys and values.
//
// Returns a disposable that can be used to stop the observation.
- (RACDisposable *)rac_observeKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer block:(void(^)(id value, NSDictionary *change))block;

@end

typedef void (^RACKVOBlock)(id target, id observer, NSDictionary *change);

@interface NSObject (RACKVOWrapperDeprecated)

- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block __attribute((deprecated("Use rac_observeKeyPath:options:observer:block: instead.")));

@end
