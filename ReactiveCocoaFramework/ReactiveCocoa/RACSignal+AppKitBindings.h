//
//  RACSignal+AppKitBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSignal.h"

@class RACChannelTerminal;
@protocol RACSubscriber;

@interface RACSignal (AppKitBindings)

/// Invokes -bind:onObject:options: without any options.
- (RACSignal *)bind:(NSString *)binding onObject:(id)bindableObject;

/// Applies a Cocoa binding to the given object, setting it to any values the
/// receiver sends, and forwarding any new binding values on the returned
/// signal.
///
/// Creating two of the same bindings on the same object will result in undefined
/// behavior.
///
/// binding        - The name of the binding. Must not be nil.
/// bindableObject - The object that should be bound. Must not be nil.
/// options        - Any options to pass to Cocoa Bindings. May be nil.
///
/// Returns a signal which, upon subscription, will start binding the receiver's
/// values to the `bindableObject`, and start forwarding new binding values. The
/// signal will complete when the input signal completes or the `bindableObject`
/// deallocates, and will error if the input signal errors.
- (RACSignal *)bind:(NSString *)binding onObject:(id)bindableObject options:(NSDictionary *)options;

@end

@interface NSObject (RACAppKitBindingsDeprecated)

- (RACChannelTerminal *)rac_channelToBinding:(NSString *)binding RACDeprecated("Use -[RACSignal bind:onObject:] instead");
- (RACChannelTerminal *)rac_channelToBinding:(NSString *)binding options:(NSDictionary *)options RACDeprecated("Use -[RACSignal bind:onObject:options:] instead");

@end

@interface NSObject (RACAppKitBindingsUnavailable)

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath __attribute__((unavailable("Use -bind:toObject:withKeyPath:options: instead")));
- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue __attribute__((unavailable("Use -bind:toObject:withKeyPath:options: instead")));
- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock __attribute__((unavailable("Use -bind:toObject:withKeyPath:options: instead")));
- (void)rac_bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath __attribute__((unavailable("Use -bind:toObject:withKeyPath:options: instead")));

@end
