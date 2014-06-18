//
//  RACSignal+AppKitBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSignal+AppKitBindings.h"

#import "EXTKeyPathCoding.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOChannel.h"
#import "RACMulticastConnection.h"
#import "RACSignal+Operations.h"

#import <AppKit/AppKit.h>
#import <objc/runtime.h>

/// Used to create Cocoa Bindings through.
@interface RACBindingProxy : NSObject

@property (nonatomic, strong) id value;

@end

@implementation RACSignal (AppKitBindings)

- (RACSignal *)bind:(NSString *)binding onObject:(id)bindableObject {
	return [self bind:binding onObject:bindableObject options:nil];
}

- (RACSignal *)bind:(NSString *)binding onObject:(id)bindableObject options:(NSDictionary *)options {
	NSCParameterAssert(binding != nil);
	NSCParameterAssert(bindableObject != nil);

	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			RACBindingProxy *proxy = [[RACBindingProxy alloc] init];

			// Forward the binding's values to the returned signal.
			[RACObserve(proxy, value) subscribe:subscriber];

			// Forward the receiver's values to the binding, and terminate the
			// returned signal upon completion or error.
			[subscriber.disposable addDisposable:[self subscribeNext:^(id newValue) {
				proxy.value = newValue;
			} error:^(NSError *error) {
				[subscriber sendError:error];
			} completed:^{
				[subscriber sendCompleted];
			}]];

			// Complete the returned signal if the bound object deallocates.
			[[bindableObject rac_deallocDisposable] addDisposable:subscriber.disposable];

			// Enable the binding.
			[bindableObject bind:binding toObject:proxy withKeyPath:@keypath(proxy.value) options:options];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				[bindableObject unbind:binding];
				[[bindableObject rac_deallocDisposable] removeDisposable:subscriber.disposable];
			}]];
		}]
		setNameWithFormat:@"[%@] -bind: %@ onObject: %@ options: %@", self.name, binding, [bindableObject rac_description], options];
}

@end

@implementation RACBindingProxy

#pragma mark Properties

- (void)setValue:(id)value {
	[self willChangeValueForKey:@keypath(self.value)];
	_value = value;
	[self didChangeValueForKey:@keypath(self.value)];
}

#pragma mark NSKeyValueObserving

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
	// Generating manual notifications for `value` is simpler and more
	// performant than having KVO swizzle our class and add its own logic.
	return NO;
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

@interface RACChannelProxy : NSObject

@property (nonatomic, strong, readonly) RACChannel *channel;
@property (nonatomic, strong) id value;
@property (atomic, unsafe_unretained) id target;
@property (nonatomic, copy, readonly) NSString *bindingName;
@property (atomic, assign) void *observationInfo;

- (id)initWithTarget:(id)target bindingName:(NSString *)bindingName options:(NSDictionary *)options;

@end

@implementation NSObject (RACAppKitBindingsDeprecated)

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

#pragma clang diagnostic pop
