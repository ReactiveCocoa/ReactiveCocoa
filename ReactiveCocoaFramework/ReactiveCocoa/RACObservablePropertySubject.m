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
#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "RACCompoundDisposable.h"
#import "RACKVOTrampoline.h"
#import "RACSignal+Private.h"
#import "RACSubject.h"
#import "RACSwizzling.h"
#import "RACTuple.h"
#import <libkern/OSAtomic.h>

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

@interface NSObject (RACObservablePropertyObserving)

// Adds the given blocks as the callbacks for when the key path changes and
// calls them immediately. Unlike direct KVO observation this handles
// deallocation of intermediate objects.
//
// The blocks are passed whether the change was triggered by last key path
// component or by the deallocation or change of an intermediate key path
// component, and the new value of the key path if applicable. The observer does
// not need to be explicitly removed. It will be removed when the observer or
// the receiver deallocate. The blocks can be called on different threads, but
// will not be called concurrently.
//
// observer        - The object that requested the observation.
// keyPath         - The key path to observe.
// willChangeBlock - The block called before the value at the key path changes.
// didChangeBlock  - The block called after the value at the key path changes.
//
// Returns a disposable that can be used to stop the observation.
- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void(^)(BOOL triggeredByLastKeyPathComponent))willChangeBlock didChangeBlock:(void(^)(BOOL triggeredByLastKeyPathComponent, id value))didChangeBlock;

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
	} didChangeBlock:^(BOOL triggeredByLastKeyPathComponent, id value) {
		if (!triggeredByLastKeyPathComponent) {
			[updatesSubject sendNext:value];
			return;
		}
		if (stackDepth > 0) --stackDepth;
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

@implementation NSObject (RACObservablePropertyObserving)

- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void (^)(BOOL))willChangeBlock didChangeBlock:(void (^)(BOOL, id))didChangeBlock {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *firstKeyPathComponent = keyPathComponents[0];
	NSString *keyPathByDeletingFirstKeyPathComponent = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;
	
	@unsafeify(observer);
	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	__block RACCompoundDisposable *childDisposable = nil;
	
	RACKVOTrampoline *trampoline = [self rac_addObserver:observer forKeyPath:firstKeyPathComponent options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionInitial block:^(id trampolineTarget, id trampolineObserver, NSDictionary *change) {
		@strongify(observer);
		
		if (keyPathComponentsCount > 1) {
			NSObject *value = [trampolineTarget valueForKey:firstKeyPathComponent];
			if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
				if (value == nil) {
					@synchronized (observer) {
						willChangeBlock(NO);
					}
				}
				return;
			}
			if (value == nil) {
				@synchronized (observer) {
					didChangeBlock(NO, nil);
				}
				return;
			}
			@synchronized (disposable) {
				[childDisposable dispose];
				[disposable removeDisposable:childDisposable];
				childDisposable = [RACCompoundDisposable compoundDisposable];
				[disposable addDisposable:childDisposable];
			}
			[childDisposable addDisposable:[value rac_addObserver:observer forKeyPath:keyPathByDeletingFirstKeyPathComponent willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock]];
			
			RACCompoundDisposable *valueDisposable = value.rac_deallocDisposable;
			RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
				@strongify(observer);
				@synchronized (observer) {
					didChangeBlock(NO, nil);
				}
			}];
			[valueDisposable addDisposable:deallocDisposable];
			[childDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[valueDisposable removeDisposable:deallocDisposable];
			}]];
			
			return;
		}
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			@synchronized (observer) {
				willChangeBlock(YES);
			}
			return;
		}
		@synchronized (observer) {
			didChangeBlock(YES, [trampolineTarget valueForKey:firstKeyPathComponent]);
		}
	}];
	
	[disposable addDisposable:[RACDisposable disposableWithBlock:^{
		[trampoline stopObserving];
	}]];
	return disposable;
}

@end
