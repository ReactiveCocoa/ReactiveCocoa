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
#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"
#import "RACSignal+Private.h"
#import "RACSubject.h"
#import "RACSwizzling.h"
#import "RACTuple.h"

// Name of exceptions thrown by RACKVOBinding when an object calls
// -didChangeValueForKey: without a corresponding -willChangeValueForKey:.
static NSString * const RACKVOBindingExceptionName = @"RACKVOBinding exception";

// Name of the key associated with the instance that threw the exception in the
// userInfo dictionary in exceptions thrown by RACKVOBinding, if applicable.
static NSString * const RACKVOBindingExceptionBindingKey = @"RACKVOBindingExceptionBindingKey";

@interface RACObservablePropertySubject ()

// The object whose key path the RACObservablePropertySubject is wrapping.
@property (atomic, unsafe_unretained) id target;

// The key path the RACObservablePropertySubject is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// The signal exposed to callers. The RACObservablePropertySubject will behave
// like this signal towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The RACObservablePropertySubject will
// behave like this subscriber towards the signals it's subscribed to.
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

// A binding to a KVO compliant key path on an object.
@interface RACKVOBinding : RACBinding

// Create a new binding for `keyPath` on `target`.
+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath;

// The object whose key path the binding is wrapping.
@property (atomic, unsafe_unretained) id target;

// The key path the binding is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// The signal exposed to callers. The binding will behave like this signal
// towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The backing subject for the binding's outgoing changes. Any time the value of
// the key path the binding is wrapping is changed, the new value is sent to
// this subject.
@property (nonatomic, readonly, strong) RACSubject *exposedSignalSubject;

// The backing subject for the binding's incoming changes. Any time a value is
// sent to this subject, the key path the binding is wrapping is set to
// that value.
@property (nonatomic, readonly, strong) RACSubject *exposedSubscriberSubject;

// The identifier of the internal KVO observer.
@property (nonatomic, readonly, strong) RACKVOTrampoline *observer;

// Whether the binding has been disposed or not. Should only be accessed while
// synchronized on self.
@property (nonatomic, getter = isDisposed) BOOL disposed;

// Current depth of the willChangeValueForKey:/didChangeValueForKey: call stack.
@property (nonatomic) NSUInteger stackDepth;

// Whether the next change of the property that occurs while `stackDepth` is 0
// should be ignored.
@property (nonatomic) BOOL ignoreNextUpdate;

// This method is called when the `target`'s `keyPath` will change.
- (void)targetWillChangeValue;

// This method is called when the `target`'s `keyPath` did change.
- (void)targetDidChangeValue;

// Dispose the binding, removing it from the `target`. Also terminates all
// subscriptions to and by the binding.
- (void)dispose;

@end

@implementation RACKVOBinding

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.exposedSignal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.exposedSubscriberSubject sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.exposedSubscriberSubject sendError:error];
}

- (void)sendCompleted {
	[self.exposedSubscriberSubject sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.exposedSubscriberSubject didSubscribeWithDisposable:disposable];
}

#pragma mark API

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath {
	RACKVOBinding *binding = [[self alloc] init];
	if (binding == nil) return nil;
	
	@weakify(binding);
	binding->_target = target;
	binding->_keyPath = [keyPath copy];
	
	binding->_exposedSignal = [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(binding);
		[subscriber sendNext:[binding.target valueForKeyPath:binding.keyPath]];
		return [binding.exposedSignalSubject subscribe:subscriber];
	}] setNameWithFormat:@"[+propertyWithTarget: %@ keyPath: %@] -binding", [target rac_description], keyPath];
	binding->_exposedSignalSubject = [RACSubject subject];
	
	binding->_exposedSubscriberSubject = [RACSubject subject];
	[binding->_exposedSubscriberSubject subscribeNext:^(id x) {
		@strongify(binding);
		if (binding.keyPath.rac_keyPathComponents.count > 1 && [binding.target valueForKeyPath:binding.keyPath.rac_keyPathByDeletingLastKeyPathComponent] == nil) {
			return;
		}
		binding.ignoreNextUpdate = YES;
		[binding.target setValue:x forKeyPath:binding.keyPath];
	}];
	
	binding->_observer = [target rac_addObserver:binding forKeyPath:keyPath options:NSKeyValueObservingOptionPrior block:^(id target, id observer, NSDictionary *change) {
		@strongify(binding);
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			[binding targetWillChangeValue];
		} else {
			[binding targetDidChangeValue];
		}
	}];

	[target rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(binding);
		[binding dispose];
	}]];
	
	return binding;
}

- (void)targetWillChangeValue {
	++self.stackDepth;
}

- (void)targetDidChangeValue {
	--self.stackDepth;
	if (self.stackDepth == NSUIntegerMax) @throw [NSException exceptionWithName:RACKVOBindingExceptionName reason:@"Receiver called -didChangeValueForKey: without corresponding -willChangeValueForKey:" userInfo:@{ RACKVOBindingExceptionBindingKey : self }];
	if (self.stackDepth != 0) return;
	if (self.ignoreNextUpdate) {
		self.ignoreNextUpdate = NO;
		return;
	}
	id value = [self.target valueForKeyPath:self.keyPath];
	[self.exposedSignalSubject sendNext:value];
}

- (void)dispose {
	self.target = nil;

	@synchronized(self) {
		if (self.disposed) return;
		self.disposed = YES;
		[self.exposedSignalSubject sendCompleted];
		[self.exposedSubscriberSubject sendCompleted];
		[self.observer dispose];
	}
}

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

+ (instancetype)propertyWithTarget:(id)target keyPath:(NSString *)keyPath {
	RACObservablePropertySubject *property = [[self alloc] init];
	if (property == nil) return nil;
	
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
		NSLog(@"Received error in binding for key path \"%@\" on %@: %@", property.keyPath, property.target, error);
	} completed:nil];

	[target rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		@strongify(property);
		property.target = nil;
	}]];
	
	return property;
}

- (RACBinding *)binding {
	return [RACKVOBinding bindingWithTarget:self.target keyPath:self.keyPath];
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
