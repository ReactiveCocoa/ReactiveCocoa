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
//
// This class is not meant to be instanced directly, but only subclassed. Call
// `+bindingWithTarget:keyPath:` to get an instance of the appropriate subclass.
@interface RACKVOBinding : RACBinding

// Create a new binding for `keyPath` on `target`.
+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath;

// Designated initializer.
//
// This should only be called from subclass initializers.
//
// target        - The object whose key path the binding is wrapping.
// key           - The first key of the key path the binding is wrapping.
// exposedSignal - The signal exposed to callers. The binding will behave like
//                 this signal towards it's subscribers. Must send the current
//                 value of the wrapped key path on subscription, then forward
//                 values sent to `exposedSignalSubject`.
- (instancetype)initWithTarget:(id)target key:(NSString *)key exposedSignal:(RACSignal *)exposedSignal;

// The object whose key path the binding is wrapping.
@property (atomic, unsafe_unretained) id target;

// The first key of the key path the binding is wrapping.
@property (nonatomic, readonly, copy) NSString *key;

// The signal exposed to callers. The binding will behave like this signal
// towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The backing subject for the binding's outgoing changes. Any time the value of
// the key path the binding is wrapping is changed, the new value must be sent
// to this subject.
@property (nonatomic, readonly, strong) RACSubject *exposedSignalSubject;

// The backing subject for the binding's incoming changes. Any time a value is
// sent to this subject, the key path the binding is wrapping must be set to
// that value.
@property (nonatomic, readonly, strong) RACSubject *exposedSubscriberSubject;

// The identifier of the internal KVO observer.
@property (nonatomic, readonly, strong) RACKVOTrampoline *observer;

// Whether the binding has been disposed or not. Should only be accessed while
// synchronized on self. Subclasses must not change it's value, they should call
// the superclass implementation of `-dispose` instead.
@property (nonatomic, getter = isDisposed) BOOL disposed;

// This method is called when the `target`'s `key` will change. Subclasses must
// override this method, and not call the superclass implementation in it.
- (void)targetWillChangeValue;

// This method is called when the `target`'s `key` did change. Subclasses must
// override this method, and not call the superclass implementation in it.
- (void)targetDidChangeValue;

// Dispose the binding, removing it from the `target`. Also terminates all
// subscriptions to and by the binding.
- (void)dispose;

@end

// A binding to a KVO compliant property on an object.
@interface RACKeyKVOBinding : RACKVOBinding

// Current depth of the willChangeValueForKey:/didChangeValueForKey: call stack.
@property (nonatomic) NSUInteger stackDepth;

// Whether the next change of the property that occurs while `stackDepth` is 0
// should be ignored.
@property (nonatomic) BOOL ignoreNextUpdate;

@end

// A binding to a KVO compliant key path on an object. The key path must have at
// least two keys.
@interface RACRemainderKVOBinding : RACKVOBinding

// The key path the binding is wrapping minus the first key.
@property (nonatomic, readonly, copy) NSString *remainder;

// The binding to `remainder` on the object value of `key`.
@property (nonatomic, strong) RACKVOBinding *remainderBinding;

// The disposable added to the value of `key`.
@property (nonatomic, weak) RACDisposable *remainderDeallocDisposable;

// Called when the current value of `key` is deallocated.
- (void)remainderDidDealloc;

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
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	if (keyPath.rac_keyPathComponents.count > 1) {
		return [RACRemainderKVOBinding bindingWithTarget:target keyPath:keyPath];
	} else {
		return [RACKeyKVOBinding bindingWithTarget:target keyPath:keyPath];
	}
}

- (instancetype)initWithTarget:(id)target key:(NSString *)key exposedSignal:(RACSignal *)exposedSignal {
	NSCParameterAssert(exposedSignal != nil);
	self = [super init];
	if (self == nil || target == nil || key == nil) return nil;
	
	_target = target;
	_key = [key copy];
	_exposedSignal = [exposedSignal setNameWithFormat:@"[+propertyWithTarget: %@ keyPath: %@] -binding", [target rac_description], key];
	_exposedSignalSubject = [RACSubject subject];
	_exposedSubscriberSubject = [RACSubject subject];
	@weakify(self);
	_observer = [_target rac_addObserver:self forKeyPath:key options:NSKeyValueObservingOptionPrior block:^(id _, id __, NSDictionary *change) {
		@strongify(self);
		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			[self targetWillChangeValue];
		} else {
			[self targetDidChangeValue];
		}
	}];
	[_target rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		[self dispose];
	}]];
	
	return self;
}

- (void)targetWillChangeValue {
	NSCAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)targetDidChangeValue {
	NSCAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)dispose {
	@synchronized(self) {
		if (self.disposed) return;
		self.disposed = YES;
		[self.exposedSignalSubject sendCompleted];
		[self.exposedSubscriberSubject sendCompleted];
		[self.observer stopObserving];
	}
}

@end

@implementation RACKeyKVOBinding

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count == 1);
	RACSignal *signal = [[RACSignal alloc] init];
	RACKeyKVOBinding *binding = [[self alloc] initWithTarget:target key:keyPath exposedSignal:signal];
	if (binding == nil) return nil;
	
	@weakify(binding);
	signal.didSubscribe = ^(id<RACSubscriber> subscriber) {
		@strongify(binding);
		[subscriber sendNext:[binding.target valueForKey:binding.key]];
		return [binding.exposedSignalSubject subscribe:subscriber];
	};
	[binding.exposedSubscriberSubject subscribeNext:^(id x) {
		@strongify(binding);
		binding.ignoreNextUpdate = YES;
		[binding.target setValue:x forKey:binding.key];
	}];
	
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
	id value = [self.target valueForKey:self.key];
	[self.exposedSignalSubject sendNext:value];
}

@end

@implementation RACRemainderKVOBinding

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 1);
	NSString *key = keyPath.rac_keyPathComponents[0];
	NSString *remainder = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;
	RACSignal *signal = [[RACSignal alloc] init];
	RACRemainderKVOBinding *binding = [[self alloc] initWithTarget:target key:key exposedSignal:signal];
	if (binding == nil) return nil;
	
	@weakify(binding);
	binding->_remainder = remainder;
	id remainderTarget = [target valueForKey:key];
	binding.remainderBinding = [RACKVOBinding bindingWithTarget:remainderTarget keyPath:remainder];
	binding.remainderDeallocDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(binding);
		[binding remainderDidDealloc];
	}];
	[remainderTarget rac_addDeallocDisposable:binding.remainderDeallocDisposable];
	signal.didSubscribe = ^(id<RACSubscriber> subscriber) {
		@strongify(binding);
		[subscriber sendNext:[[binding.target valueForKey:key] valueForKeyPath:binding.remainder]];
		return [binding.exposedSignalSubject subscribe:subscriber];
	};
	[binding.exposedSubscriberSubject subscribeNext:^(id x) {
		@strongify(binding);
		[binding.remainderBinding.exposedSubscriberSubject sendNext:x];
	}];
	
	return binding;
}

- (void)targetWillChangeValue {
	[[[self.target valueForKey:self.key] rac_deallocDisposable] removeDisposable:self.remainderDeallocDisposable];
	self.remainderBinding = nil;
	[self.remainderBinding dispose];
}

- (void)targetDidChangeValue {
	id remainderTarget = [self.target valueForKey:self.key];
	if (remainderTarget == nil) {
		self.remainderBinding = nil;
		[self.exposedSignalSubject sendNext:nil];
	}

	@weakify(self);
	self.remainderBinding = [RACKVOBinding bindingWithTarget:remainderTarget keyPath:self.remainder];
	self.remainderDeallocDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);
		[self remainderDidDealloc];
	}];
	[remainderTarget rac_addDeallocDisposable:self.remainderDeallocDisposable];
}

- (void)dispose {
	self.target = nil;

	@synchronized(self) {
		if (self.disposed) return;
		[super dispose];
		[self.remainderBinding dispose];
	}
}

- (void)setRemainderBinding:(RACKVOBinding *)remainderBinding {
	if (remainderBinding == _remainderBinding) return;
	[_remainderBinding dispose];
	_remainderBinding = remainderBinding;
	@weakify(self);
	[_remainderBinding subscribeNext:^(id x) {
		@strongify(self);
		[self.exposedSignalSubject sendNext:x];
	}];
}

- (void)remainderDidDealloc {
	[self.exposedSignalSubject sendNext:nil];
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
