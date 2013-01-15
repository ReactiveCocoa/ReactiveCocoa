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

@class RACKVOTrampoline;

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

@end
