//
//  RACObservablePropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACObservablePropertySubject.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACObservablePropertyObserving.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACBinding.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"

@interface RACObservablePropertySubject ()

// The object whose key path the RACObservablePropertySubject is wrapping.
@property (atomic, unsafe_unretained) NSObject *target;

// The key path the RACObservablePropertySubject is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// The signal exposed to callers. The RACObservablePropertySubject will behave
// like this signal towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The RACObservablePropertySubject will
// behave like this subscriber towards the signals it's subscribed to.
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

// A binding to a key path on an object.
@interface RACObservablePropertyBinding : RACBinding

// Create a new binding for `keyPath` on `target`.
+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath;

// The object whose key path the binding is wrapping.
@property (atomic, unsafe_unretained) NSObject *target;

// The key path the binding is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// The signal exposed to callers. The binding will behave like this signal
// towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The binding will behave like this
// subscriber towards the signals it's subscribed to.
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

@implementation RACObservablePropertySubject

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.exposedSignal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.exposedSubscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.exposedSubscriber sendError:error];
}

- (void)sendCompleted {
	[self.exposedSubscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.exposedSubscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

+ (instancetype)propertyWithTarget:(NSObject *)target keyPath:(NSString *)keyPath {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	RACObservablePropertySubject *property = [[self alloc] init];
	if (property == nil || target == nil) return nil;
	
	property->_target = target;
	property->_keyPath = [keyPath copy];
	
	@weakify(property);
	
	property->_exposedSignal = [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(property);
		[subscriber sendNext:[property.target valueForKeyPath:keyPath]];
		return [[property.target rac_signalForKeyPath:property.keyPath observer:property] subscribe:subscriber];
	}] setNameWithFormat:@"+propertyWithTarget: %@ keyPath: %@", [target rac_description], keyPath];
	
	property->_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(property);
		[property.target setValue:x forKeyPath:property.keyPath];
	} error:^(NSError *error) {
		@strongify(property);
		NSCAssert(NO, @"Received error in RACObservablePropertySubject for key path \"%@\" on %@: %@", property.keyPath, property.target, error);
		
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACObservablePropertySubject for key path \"%@\" on %@: %@", property.keyPath, property.target, error);
	} completed:nil];
	
	[target.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(property);
		property.target = nil;
	}]];
	
	return property;
}

- (RACBinding *)binding {
	return [RACObservablePropertyBinding bindingWithTarget:self.target keyPath:self.keyPath];
}

@end

@implementation RACObservablePropertySubject (RACBind)

- (id)objectForKeyedSubscript:(id)key {
	return [self valueForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
	[[self valueForKey:key] bindTo:obj];
}

@end

@implementation RACObservablePropertyBinding

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.exposedSignal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.exposedSubscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.exposedSubscriber sendError:error];
}

- (void)sendCompleted {
	[self.exposedSubscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.exposedSubscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

+ (instancetype)bindingWithTarget:(NSObject *)target keyPath:(NSString *)keyPath {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	RACObservablePropertyBinding *binding = [[self alloc] init];
	if (binding == nil || target == nil) return nil;
	
	binding->_target = target;
	binding->_keyPath = [keyPath copy];
	
	@weakify(binding);

	// The flag used to ignore updates the binding itself has triggered.
	__block BOOL ignoreNextUpdate = NO;

	// The depth of the current -willChangeValueForKey: / -didChangeValueForKey:
	// call stack.
	__block NSUInteger stackDepth = 0;

	// The subject used to multicast changes to the property to the binding's
	// subscribers.
	RACSubject *updatesSubject = [RACSubject subject];

	// Observe the key path on target for changes. Update the value of stackDepth
	// accordingly and forward the changes to updatesSubject.
	[target rac_addObserver:binding forKeyPath:keyPath willChangeBlock:^(BOOL triggeredByLastKeyPathComponent) {
		// The binding only triggers changes to the last path component, no need to
		// track the stack depth if this is not the case.
		if (!triggeredByLastKeyPathComponent) return;
		++stackDepth;
	} didChangeBlock:^(BOOL triggeredByLastKeyPathComponent, BOOL triggeredByDeallocation, id value) {
		// The binding only triggers changes to the last path component, if the
		// change wasn't triggered by the last path component, or was triggered by
		// a deallocation, it definitely wasn't triggered by this binding, so just
		// forward it.
		if (!triggeredByLastKeyPathComponent || triggeredByDeallocation) {
			[updatesSubject sendNext:value];
			return;
		}

		--stackDepth;
		NSCAssert(stackDepth != NSUIntegerMax, @"%@ called didChangeValueForKey: without corresponding willChangeValueForKey:", keyPath);
		// If the current stackDepth is greater than 0, then the change was
		// triggered by a callback on -willChangeValueForKey:, and not by the
		// binding itself. If however the stackDepth is 0, and ignoreNextUpdate is
		// set, the changes was triggered by this binding and should not be
		// forwarded.
		if (stackDepth == 0 && ignoreNextUpdate) {
			ignoreNextUpdate = NO;
			return;
		}
		[updatesSubject sendNext:value];
	}];

	// On subscription first send the property's current value then subscribe the
	// subscriber to the updatesSubject for new values when they change.
	binding->_exposedSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(binding);
		[subscriber sendNext:[binding.target valueForKeyPath:binding.keyPath]];
		return [updatesSubject subscribe:subscriber];
	}];
	
	NSString *keyPathByDeletingLastKeyPathComponent = keyPath.rac_keyPathByDeletingLastKeyPathComponent;
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *lastKeyPathComponent = keyPathComponents.lastObject;

	// Update the value of the property with the values received.
	binding->_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(binding);

		// Check the value of the second to last key path component. Since the
		// binding can only update the value of a property on an object, and not
		// update intermediate objects, it can only update the value of the whole
		// key path if this object is not nil.
		NSObject *object = (keyPathComponentsCount > 1 ? [binding.target valueForKeyPath:keyPathByDeletingLastKeyPathComponent] : binding.target);
		if (object == nil) return;

		// Set the ignoreNextUpdate flag before setting the value so this binding
		// ignores the value in the subsequent -didChangeValueForKey: callback.
		ignoreNextUpdate = YES;
		[object setValue:x forKey:lastKeyPathComponent];
	} error:^(NSError *error) {
		@strongify(binding);
		NSCAssert(NO, @"Received error in -[RACObservablePropertySubject binding] for key path \"%@\" on %@: %@", binding.keyPath, binding.target, error);
		
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in -[RACObservablePropertySubject binding] for key path \"%@\" on %@: %@", binding.keyPath, binding.target, error);
	} completed:nil];
	
	[target.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(binding);
		binding.target = nil;
	}]];
	
	return binding;
}

@end
