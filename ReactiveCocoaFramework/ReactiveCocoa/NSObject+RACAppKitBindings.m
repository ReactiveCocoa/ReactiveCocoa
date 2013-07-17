//
//  NSObject+RACAppKitBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/17/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACAppKitBindings.h"
#import "EXTKeyPathCoding.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "RACBinding.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACMulticastConnection.h"
#import "RACObservablePropertySubject.h"
#import "RACPropertySubject.h"
#import "RACSignal+Operations.h"
#import "RACValueTransformer.h"
#import <objc/runtime.h>

// Used as an object to bind to, so we can hide the object creation and just
// expose a RACBinding instead.
@interface RACBindingProxy : NSObject

// The subject from which the receiver's RACBindings will be derived.
@property (nonatomic, strong, readonly) RACPropertySubject *propertySubject;

// The binding to expose to the caller (typically a model, view model, or
// controller object).
@property (nonatomic, strong, readonly) RACBinding *modelBinding;

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
// Returns an initialized binding proxy.
- (id)initWithTarget:(id)target bindingName:(NSString *)bindingName options:(NSDictionary *)options;

@end

@implementation NSObject (RACAppKitBindings)

- (RACBinding *)rac_bind:(NSString *)binding {
	return [self rac_bind:binding options:nil];
}

- (RACBinding *)rac_bind:(NSString *)binding options:(NSDictionary *)options {
	NSCParameterAssert(binding != nil);

	RACBindingProxy *proxy = [[RACBindingProxy alloc] initWithTarget:self bindingName:binding options:options];
	return proxy.modelBinding;
}

@end

@implementation RACBindingProxy

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

	_propertySubject = [[RACPropertySubject property] setNameWithFormat:@"%@ -propertySubject", self];
	_modelBinding = [[self.propertySubject binding] setNameWithFormat:@"%@ -modelBinding", self];

	@weakify(self);

	void (^cleanUp)() = ^{
		@strongify(self);

		id target = self.target;
		if (target == nil) return;

		self.target = nil;

		[target unbind:bindingName];
		objc_setAssociatedObject(target, (__bridge void *)self, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	};

	// When the property subject terminates (from anything), tear down this
	// proxy.
	[self.propertySubject subscribeError:^(NSError *error) {
		cleanUp();
	} completed:cleanUp];

	[self.target bind:bindingName toObject:self withKeyPath:@keypath(self.value) options:options];

	// Keep the proxy alive as long as the target, or until the property subject
	// terminates.
	objc_setAssociatedObject(self.target, (__bridge void *)self, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	[[self.target rac_deallocDisposable] addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(self);
		[self.propertySubject sendCompleted];
	}]];

	RACBind(self, value, options[NSNullPlaceholderBindingOption]) = [self.propertySubject binding];
	return self;
}

- (void)dealloc {
	[self.propertySubject sendCompleted];
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

@implementation NSObject (RACAppKitBindingsDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self rac_bind:binding toObject:object withKeyPath:keyPath nilValue:nil];
}

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nilValue, NSNullPlaceholderBindingOption, nil]];
}

- (void)rac_bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock {
	RACValueTransformer *transformer = [RACValueTransformer transformerWithBlock:transformBlock];
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, transformer, NSValueTransformerBindingOption, nil]];
}

- (void)rac_bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
}

#pragma clang diagnostic pop

@end
