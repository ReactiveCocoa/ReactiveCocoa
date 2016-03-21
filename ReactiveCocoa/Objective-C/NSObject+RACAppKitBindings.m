//
//  NSObject+RACAppKitBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACAppKitBindings.h"
#import <ReactiveCocoa/EXTKeyPathCoding.h>
#import <ReactiveCocoa/EXTScope.h>
#import "NSObject+RACDeallocating.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOChannel.h"
#import "RACValueTransformer.h"
#import <objc/runtime.h>

// Used as an object to bind to, so we can hide the object creation and just
// expose a RACChannel instead.
@interface RACChannelProxy : NSObject

// The RACChannel used for this Cocoa binding.
@property (nonatomic, strong, readonly) RACChannel *channel;

// The KVC- and KVO-compliant property to be read and written by the Cocoa
// binding.
//
// This should not be set manually.
@property (nonatomic, strong) id value;

// The target of the Cocoa binding.
//
// This should be set to nil when the target deallocates.
@property (atomic, unsafe_unretained) id target;

// The name of the Cocoa binding used.
@property (nonatomic, copy, readonly) NSString *bindingName;

// Improves the performance of KVO on the receiver.
//
// See the documentation for <NSKeyValueObserving> for more information.
@property (atomic, assign) void *observationInfo;

// Initializes the receiver and binds to the given target.
//
// target      - The target of the Cocoa binding. This must not be nil.
// bindingName - The name of the Cocoa binding to use. This must not be nil.
// options     - Any options to pass to the binding. This may be nil.
//
// Returns an initialized channel proxy.
- (id)initWithTarget:(id)target bindingName:(NSString *)bindingName options:(NSDictionary *)options;

@end

@implementation NSObject (RACAppKitBindings)

- (RACChannelTerminal *)rac_channelToBinding:(NSString *)binding {
	return [self rac_channelToBinding:binding options:nil];
}

- (RACChannelTerminal *)rac_channelToBinding:(NSString *)binding options:(NSDictionary *)options {
	NSCParameterAssert(binding != nil);

	RACChannelProxy *proxy = [[RACChannelProxy alloc] initWithTarget:self bindingName:binding options:options];
	return proxy.channel.leadingTerminal;
}

@end

@implementation RACChannelProxy

#pragma mark Properties

- (void)setValue:(id)value {
	[self willChangeValueForKey:@keypath(self.value)];
	_value = value;
	[self didChangeValueForKey:@keypath(self.value)];
}

#pragma mark Lifecycle

- (id)initWithTarget:(id)target bindingName:(NSString *)bindingName options:(NSDictionary *)options {
	NSCParameterAssert(target != nil);
	NSCParameterAssert(bindingName != nil);

	self = [super init];
	if (self == nil) return nil;

	_target = target;
	_bindingName = [bindingName copy];
	_channel = [[RACChannel alloc] init];

	@weakify(self);

	void (^cleanUp)() = ^{
		@strongify(self);

		id target = self.target;
		if (target == nil) return;

		self.target = nil;

		[target unbind:bindingName];
		objc_setAssociatedObject(target, (__bridge void *)self, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	};

	// When the channel terminates, tear down this proxy.
	[self.channel.followingTerminal subscribeError:^(NSError *error) {
		cleanUp();
	} completed:cleanUp];

	[self.target bind:bindingName toObject:self withKeyPath:@keypath(self.value) options:options];

	// Keep the proxy alive as long as the target, or until the property subject
	// terminates.
	objc_setAssociatedObject(self.target, (__bridge void *)self, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	[[self.target rac_deallocDisposable] addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(self);
		[self.channel.followingTerminal sendCompleted];
	}]];

	RACChannelTo(self, value, options[NSNullPlaceholderBindingOption]) = self.channel.followingTerminal;
	return self;
}

- (void)dealloc {
	[self.channel.followingTerminal sendCompleted];
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ target: %@, binding: %@ }", self.class, self, self.target, self.bindingName];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// Generating manual notifications for `value` is simpler and more
	// performant than having KVO swizzle our class and add its own logic.
	return NO;
}

@end
