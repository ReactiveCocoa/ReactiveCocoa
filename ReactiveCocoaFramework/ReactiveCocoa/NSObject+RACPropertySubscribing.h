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

// Returns a subscribable for the given property on the given object.
#define RACAble(object, property) [object rac_subscribableForKeyPath:RAC_KEYPATH(object, property) onObject:self]

// Same as RACAble but the subscribable also starts with the current value of
// the property.
#define RACAbleWithStart(object, property) [RACAble(object, property) startWith:[object valueForKeyPath:RAC_KEYPATH(object, property)]]

// Returns a subscribable for the given property on self.
#define RACAbleSelf(property) RACAble(self, property)

// Same as RACAbleSelf but the subscribable also starts with the current value
// of the property.
#define RACAbleSelfWithStart(property) RACAbleWithStart(self, property)

#define RACAbleKeyPath(keyPath) [self rac_subscribableForKeyPath:keyPath onObject:self]

@class RACSubscribable;
@class RACDisposable;


@interface NSObject (RACPropertySubscribing)

// Creates a subscribable for observing on the given object the key path of the
// source object.
+ (RACSubscribable *)rac_subscribableFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject;

// Creates a value from observing the value at the given keypath.
- (RACSubscribable *)rac_subscribableForKeyPath:(NSString *)keyPath onObject:(NSObject *)object;

// Keeps the value of the KVC-compliant keypath up-to-date with the latest value
// sent by the subscribable.
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSubscribable *)subscribable;

@end
