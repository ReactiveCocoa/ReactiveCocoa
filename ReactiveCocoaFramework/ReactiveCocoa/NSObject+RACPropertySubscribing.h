//
//  NSObject+RACPropertySubscribing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RAC_KEYPATH(object, property) ((void)(NO && ((void)object.property, NO)), @#property)
#define RAC_KEYPATH_SELF(property) RAC_KEYPATH(self, property)

#define RACAble(object, property) [object rac_subscribableForKeyPath:RAC_KEYPATH(object, property) onObject:self]
#define RACAbleWithStart(object, property) [RACAble(object, property) startWith:[object valueForKey:RAC_KEYPATH(object, property)]]
#define RACAbleSelf(property) RACAble(self, property)
#define RACAbleSelfWithStart(property) RACAbleWithStart(self, property)

@class RACSubscribable;


@interface NSObject (RACPropertySubscribing)

// Creates a subscribable for observing on the given object the key path of the
// source object.
+ (RACSubscribable *)rac_subscribableFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject;

// Creates a value from observing the value at the given keypath.
- (RACSubscribable *)rac_subscribableForKeyPath:(NSString *)keyPath onObject:(NSObject *)object;

@end
