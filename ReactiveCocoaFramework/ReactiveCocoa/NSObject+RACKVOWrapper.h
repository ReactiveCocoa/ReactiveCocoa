//
//  NSObject+RACKVOWrapper.h
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSObject (RACKVOWrapper)

// Adds the given block as the callback for when the keyPath changes. The
// observer does not need to be explicitly removed. It will be removed when the
// target or observed object is dealloc'd.
//
// target - the object to which callbacks will be delivered. This is passed back
// into the target block.
//
// keyPath - the key path to observe
//
// options - the key-value observing options
//
// queue - the queue in which the callback block should be performed. Passing
// nil means the block will be performed in whatever queue the observer callback
// came in on.
//
// block - the block called when the value at the key path changes.
//
// Returns an identifier that can be used to remove the observer.
- (id)rac_addObserver:(NSObject *)target forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(void (^)(id target, NSDictionary *change))block;

// Remove the observer represented by the identifier.
//
// identifier - the identifier to removed. This should be an object previously
// returned by a called to -addObserverForKeyPath:options:queue:block:.
//
// Returns whether the removal was successful. The only reason for failure would
// be if the identifier doesn't represent anything currently being observed by
// the object, or if the identifier is nil.
- (BOOL)rac_removeObserverWithIdentifier:(id)identifier;

@end
