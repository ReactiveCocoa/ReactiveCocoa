//
//  NSObject+RACAppKitBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RACBinding;

@interface NSObject (RACAppKitBindings)

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]]
- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nilValue, NSNullPlaceholderBindingOption, nil]];
- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue;

// Same as `-[NSObject bind:toObject:withKeyPath:] but also transforms values
// using the given transform block.
- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock;

// Same as `-[NSObject bind:toObject:withKeyPath:] but the value is transformed
// by negating it.
- (void)rac_bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath;

// Invokes -rac_bind:options: without any options.
- (RACBinding *)rac_bind:(NSString *)binding;

// Applies a Cocoa binding to the receiver which will send and receive values
// upon the returned RACBinding.
//
// binding - The name of the binding. This must not be nil.
// options - Any options to pass to Cocoa Bindings. This may be nil.
//
// Returns a RACBinding which will send values from the receiver to its
// subscribers, and pass received values along to the binding (to be set on the
// receiver).
- (RACBinding *)rac_bind:(NSString *)binding options:(NSDictionary *)options;

@end
