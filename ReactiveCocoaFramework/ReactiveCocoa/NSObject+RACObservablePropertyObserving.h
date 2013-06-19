//
//  NSObject+RACObservablePropertyObserving.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/06/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;

@interface NSObject (RACObservablePropertyObserving)

// Adds the given blocks as the callbacks for when the key path changes. Unlike
// direct KVO observation this handles deallocation of intermediate objects.
//
// The observation does not need to be explicitly removed. It will be removed
// when the observer or the receiver deallocate. The blocks can be called on
// different threads, but will not be called concurrently.
//
// observer          - The object that requested the observation.
// keyPath           - The key path to observe.
// serializationLock - The lock used to serialize calls to willChangeBlock and
//                     didChangeBlock. If not provided, one will be created.
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
