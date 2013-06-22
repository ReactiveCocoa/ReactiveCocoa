//
//  NSObject+RACKVOWrapper.h
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>

// The block called when the KVO notification fires.
//
// target   - The object being observed.
// observer - The object doing the observing.
// change   - The KVO change dictionary, as given to
//            -observeValueForKeyPath:ofObject:change:context:.
typedef void (^RACKVOBlock)(id target, id observer, NSDictionary *change);

@class RACDisposable, RACKVOTrampoline;

@interface NSObject (RACKVOWrapper)

// Adds the given block as the callback for when the keyPath changes. The
// observer does not need to be explicitly removed. It will be removed when the
// observer or observed object is dealloc'd.
//
// observer - the object to which callbacks will be delivered. This is passed back
// into the given block.
//
// keyPath - the key path to observe
//
// options - the key-value observing options
//
// block - the block called when the value at the key path changes.
//
// Returns the KVO trampoline that can be used to stop the observation.
- (RACKVOTrampoline *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options block:(RACKVOBlock)block;

// Adds the given blocks as the callbacks for when the key path changes. Unlike
// direct KVO observation this handles deallocation of intermediate objects.
//
// The observation does not need to be explicitly removed. It will be removed
// when the observer or the receiver deallocate. The blocks can be called on
// different threads, but will not be called concurrently.
//
// observer          - The object that requested the observation.
// keyPath           - The key path to observe.
// willChangeBlock   - The block called before the value at the key path
//                     changes. It is passed whether the key path component
//                     whose value will be changed explicitly is the last one or
//                     an intermediate one.
// didChangeBlock    - The block called after the value at the key path changes.
//                     It is passed whether the key path component whose value
//                     was changed explicitly was the last one or an
//                     intermediate one, whether the change was caused by the
//                     deallocation of a value, and the new value of the key
//                     path.
//
// Returns a disposable that can be used to stop the observation.
- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void(^)(BOOL triggeredByLastKeyPathComponent))willChangeBlock didChangeBlock:(void(^)(BOOL triggeredByLastKeyPathComponent, BOOL triggeredByDeallocation, id value))didChangeBlock;

@end
