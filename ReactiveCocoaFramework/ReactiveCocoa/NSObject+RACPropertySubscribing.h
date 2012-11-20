//
//  NSObject+RACPropertySubscribing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EXTKeyPathCoding.h"
#import "metamacros.h"

// Returns a subscribable for the given keypath / property on the given object.
// If it is given one argument, the keypath / property is assumed to be on self.
// If it is given two, the first argument is the object and the second is the
// relative keypath / property.
//
// Examples:
//
//  RACSignal *subscribable1 = RACAble(self.blah);
//  RACSignal *subscribable2 = RACAble(blah, someOtherBlah);
#define RACAble(...) metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))(_RACAbleObject(self, __VA_ARGS__))(_RACAbleObject(__VA_ARGS__))

// Do not use this directly. Use RACAble above.
#define _RACAbleObject(object, property) [object rac_subscribableForKeyPath:@keypath(object, property) onObject:self]

// Same as RACAble but the subscribable also starts with the current value of
// the property.
#define RACAbleWithStart(...) [RACAble(__VA_ARGS__) startWith:_RACAbleWithStartValue(__VA_ARGS__)]

// Do not use this directly. Use RACAbleWithStart above.
#define _RACAbleWithStartValue(...) metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__))([self valueForKeyPath:@keypath(self, __VA_ARGS__)])([metamacro_at0(__VA_ARGS__) valueForKeyPath:@keypath(__VA_ARGS__)])

@class RACSignal;
@class RACDisposable;


@interface NSObject (RACPropertySubscribing)

// Creates a subscribable for observing on the given object the key path of the
// source object.
+ (RACSignal *)rac_subscribableFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject;

// Creates a value from observing the value at the given keypath.
- (RACSignal *)rac_subscribableForKeyPath:(NSString *)keyPath onObject:(NSObject *)object;

// Keeps the value of the KVC-compliant keypath up-to-date with the latest value
// sent by the subscribable.
- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)subscribable;

// Adds a disposable which will be disposed when the receiver deallocs.
- (void)rac_addDeallocDisposable:(RACDisposable *)disposable;

@end
