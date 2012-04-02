//
//  NSObject+RACPropertySubscribing.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RAC_KEYPATH(object, property) ((void)(NO && ((void)object.property, NO)), @#property)
#define RAC_KEYPATH_SELF(property) RAC_KEYPATH(self, property)

#define RACABLE(object, property) [object RACSubscribableForKeyPath:RAC_KEYPATH(object, property)]
#define RACABLE_SELF(property) RACABLE(self, property)

@class RACSubscribable;


@interface NSObject (RACPropertySubscribing)

+ (RACSubscribable *)RACSubscribableFor:(NSObject *)object keyPath:(NSString *)keyPath;

// Creates a value from observing the value at the given keypath.
- (RACSubscribable *)RACSubscribableForKeyPath:(NSString *)keyPath;

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]]
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;

// Same as `-[NSObject bind:toObject:withKeyPath:] but also transforms values using the given transform block.
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock;

// Same as `-[NSObject bind:toObject:withKeyPath:] but the value is transformed by negating it.
- (void)bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath;

@end
