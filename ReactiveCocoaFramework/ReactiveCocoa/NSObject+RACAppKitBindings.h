//
//  NSObject+RACAppKitBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (RACAppKitBindings)

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]]
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nilValue, NSNullPlaceholderBindingOption, nil]];
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue;

// Same as `-[NSObject bind:toObject:withKeyPath:] but also transforms values
// using the given transform block.
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock;

// Same as `-[NSObject bind:toObject:withKeyPath:] but the value is transformed
// by negating it.
- (void)bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath;

@end
