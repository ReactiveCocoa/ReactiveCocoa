//
//  NSObject+RACPropertyObserving.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RACKVO(property) ((void)(NO && ((void)property, NO)), @#property)
#define RACObservable(property) [self RACObservableForKeyPath:RACKVO(self.property)]

@class RACObservable;


@interface NSObject (RACPropertyObserving)

// Creates a value from observing the value at the given keypath.
- (RACObservable *)RACObservableForKeyPath:(NSString *)keyPath;

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]]
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;

// Same as `-[NSObject bind:toObject:withKeyPath:] but also transforms values using the given transform block.
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock;

// Same as `-[NSObject bind:toObject:withKeyPath:] but the value is transformed by negating it.
- (void)bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath;

@end
