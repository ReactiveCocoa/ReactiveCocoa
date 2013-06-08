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

// Adds the given blocks as the callbacks for when the key path changes and
// calls them immediately. Unlike direct KVO observation this handles
// deallocation of intermediate objects.
//
// The blocks are passed whether the change was triggered by last key path
// component or by the deallocation or change of an intermediate key path
// component, and the new value of the key path if applicable. The observer does
// not need to be explicitly removed. It will be removed when the observer or
// the receiver deallocate. The blocks can be called on different threads, but
// will not be called concurrently.
//
// observer        - The object that requested the observation.
// keyPath         - The key path to observe.
// willChangeBlock - The block called before the value at the key path changes.
// didChangeBlock  - The block called after the value at the key path changes.
//
// Returns a disposable that can be used to stop the observation.
- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void(^)(BOOL triggeredByLastKeyPathComponent))willChangeBlock didChangeBlock:(void(^)(BOOL triggeredByLastKeyPathComponent, id value))didChangeBlock;

@end
