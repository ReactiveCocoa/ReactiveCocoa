//
//  RACObservablePropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACObservablePropertySubject.h"
#import "EXTScope.h"
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
	
	[target rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
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
	__block BOOL ignoreNextUpdate = NO;
	__block NSUInteger stackDepth = 0;
	RACSubject *updatesSubject = [RACSubject subject];
	
	[target rac_addObserver:binding forKeyPath:keyPath willChangeBlock:^(BOOL triggeredByLastKeyPathComponent) {
		if (!triggeredByLastKeyPathComponent) return;
		++stackDepth;
	} didChangeBlock:^(BOOL triggeredByLastKeyPathComponent, BOOL triggeredByDeallocation, id value) {
		if (!triggeredByLastKeyPathComponent || triggeredByDeallocation) {
			[updatesSubject sendNext:value];
			return;
		}
		--stackDepth;
		NSCAssert(stackDepth != NSUIntegerMax, @"%@ called didChangeValueForKey: without corresponding willChangeValueForKey:", keyPath);
		if (stackDepth == 0 && ignoreNextUpdate) {
			ignoreNextUpdate = NO;
			return;
		}
		[updatesSubject sendNext:value];
	}];
	
	binding->_exposedSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(binding);
		[subscriber sendNext:[binding.target valueForKeyPath:binding.keyPath]];
		return [updatesSubject subscribe:subscriber];
	}];
	
	NSString *keyPathByDeletingLastKeyPathComponent = keyPath.rac_keyPathByDeletingLastKeyPathComponent;
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *lastKeyPathComponent = keyPathComponents.lastObject;
	
	binding->_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(binding);
		NSObject *object = (keyPathComponentsCount > 1 ? [binding.target valueForKeyPath:keyPathByDeletingLastKeyPathComponent] : binding.target);
		if (object == nil) return;
		ignoreNextUpdate = YES;
		[object setValue:x forKey:lastKeyPathComponent];
	} error:^(NSError *error) {
		@strongify(binding);
		NSCAssert(NO, @"Received error in -[RACObservablePropertySubject binding] for key path \"%@\" on %@: %@", binding.keyPath, binding.target, error);
		
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in -[RACObservablePropertySubject binding] for key path \"%@\" on %@: %@", binding.keyPath, binding.target, error);
	} completed:nil];
	
	[target rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(binding);
		binding.target = nil;
	}]];
	
	return binding;
}

@end
