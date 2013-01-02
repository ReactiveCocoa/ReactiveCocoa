//
//  RACKVOProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACKVOProperty.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "RACSignal+Private.h"
#import "RACSubject.h"
#import "RACSwizzling.h"
#import "RACTuple.h"
#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "EXTScope.h"

// The key for RACKVOBindings associated to an object.
static void *RACKVOBindingsKey = &RACKVOBindingsKey;

// Name of exceptions thrown by RACKVOBinding when an object calls
// -didChangeValueForKey: without a corresponding -willChangeValueForKey:.
static NSString * const RACKVOBindingExceptionName = @"RACKVOBinding exception";

// Name of the key associated with the instance that threw the exception in the
// userInfo dictionary in exceptions thrown by RACKVOBinding, if applicable.
static NSString * const RACKVOBindingExceptionBindingKey = @"RACKVOBindingExceptionBindingKey";

@interface RACKVOProperty ()

// The object whose key path the RACKVOProperty is wrapping.
@property (nonatomic, readonly, weak) id target;

// The key path the RACKVOProperty is wrapping.
@property (nonatomic, readonly, copy) NSString *keyPath;

// The signal exposed to callers. The property will behave like this signal
// towards it's subscribers.
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;

// The subscriber exposed to callers. The property will behave like this
// subscriber towards the signals it's subscribed to.
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
@property (nonatomic, readonly, weak) id target;

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

// The identifier of the internal KVO observer. See note in initializer for more
// info.
@property (nonatomic, readonly, strong) id observer;

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

@end

@interface NSObject (RACKVOBinding)

// The set of bindings wrapping the receiver. Should only be accessed while
// synchronized on self.
@property (nonatomic, strong) NSMutableSet *RACKVOBindings;

// Adds `binding` to the receiver's binding..
- (void)rac_addBinding:(RACKVOBinding *)binding;

// Removes `binding` from the receiver's bindings.
- (void)rac_removeBinding:(RACKVOBinding *)binding;

// Calls `-targetWillChangeValue` on all the receiver's bindings.
- (void)rac_customWillChangeValueForKey:(NSString *)key;

// Calls `-targetDidChangeValue` on all the receiver's bindings.
- (void)rac_customDidChangeValueForKey:(NSString *)key;

@end

// Prepares the given class for binding by swizzling willChangeValueForKey: and
// didChangeValueForKey:. Does nothing if the class has already been prepared.
static void prepareClassForBindingIfNeeded(__unsafe_unretained Class class) {
	static dispatch_once_t onceToken;
	static NSMutableSet *swizzledClasses = nil;
	dispatch_once(&onceToken, ^{
		swizzledClasses = [[NSMutableSet alloc] init];
	});
	NSString *className = NSStringFromClass(class);
	@synchronized(swizzledClasses) {
		if (![swizzledClasses containsObject:className]) {
			RACSwizzle(class, @selector(willChangeValueForKey:), @selector(rac_customWillChangeValueForKey:));
			RACSwizzle(class, @selector(didChangeValueForKey:), @selector(rac_customDidChangeValueForKey:));
			[swizzledClasses addObject:className];
		}
	}
}

// Given a key path, returns a tuple of the first key in the key path, and the
// remaining key path, if any.
static RACTuple *keyAndRemainderForKeyPath(NSString *keyPath) {
	NSRange firstDot = [keyPath rangeOfString:@"."];
	if (firstDot.location == NSNotFound) {
		return [RACTuple tupleWithObjects:keyPath, nil];
	} else {
		NSString *key = [keyPath substringToIndex:firstDot.location];
		NSString *remainder = [keyPath substringFromIndex:NSMaxRange(firstDot)];
		return [RACTuple tupleWithObjects:key, remainder, nil];
	}
}

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
	if (keyAndRemainderForKeyPath(keyPath).second != nil) {
		return [RACRemainderKVOBinding bindingWithTarget:target keyPath:keyPath];
	} else {
		return [RACKeyKVOBinding bindingWithTarget:target keyPath:keyPath];
	}
}

- (instancetype)initWithTarget:(id)target key:(NSString *)key exposedSignal:(RACSignal *)exposedSignal {
	NSParameterAssert(exposedSignal != nil);
	self = [super init];
	if (self == nil || target == nil || key == nil) return nil;
	
	_target = target;
	_key = [key copy];
	_exposedSignal = exposedSignal;
	_exposedSignalSubject = [RACSubject subject];
	_exposedSubscriberSubject = [RACSubject subject];
	prepareClassForBindingIfNeeded([_target class]);
	[_target rac_addBinding:self];
	// This KVO observer doesn't do anything, but we have to add it or
	// `-willChangeValueForKey:` and `-didChangeValueForKey:` might not get
	// called.
	// The observer is then removed when the binding is disposed, or when either
	// the target or the binding deallocate.
	_observer = [_target rac_addObserver:self forKeyPath:key options:NSKeyValueObservingOptionPrior queue:nil block:nil];
	[_target rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		[self dispose];
	}]];
	
	return self;
}

- (void)targetWillChangeValue {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)targetDidChangeValue {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendBindingValue:(id)value sender:(id)sender {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)dispose {
	@synchronized(self) {
		if (self.disposed) return;
		self.disposed = YES;
		[self.exposedSignalSubject sendCompleted];
		[self.exposedSubscriberSubject sendCompleted];
		[self.target rac_removeObserverWithIdentifier:self.observer];
		[self.target rac_removeBinding:self];
	}
}

@end

@implementation RACKeyKVOBinding

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath {
	NSParameterAssert(keyAndRemainderForKeyPath(keyPath).second == nil);
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
	RACTupleUnpack(NSString *key, NSString *remainder) = keyAndRemainderForKeyPath(keyPath);
	NSParameterAssert(remainder != nil);
	RACSignal *signal = [[RACSignal alloc] init];
	RACRemainderKVOBinding *binding = [[self alloc] initWithTarget:target key:key exposedSignal:signal];
	if (binding == nil) return nil;
	
	@weakify(binding);
	binding->_remainder = remainder;
	binding.remainderBinding = [RACKVOBinding bindingWithTarget:[target valueForKey:key] keyPath:remainder];
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
	self.remainderBinding = nil;
	[self.remainderBinding dispose];
}

- (void)targetDidChangeValue {
	id remainderTarget = [self.target valueForKey:self.key];
	if (remainderTarget == nil) {
		self.remainderBinding = nil;
		[self.exposedSignalSubject sendNext:nil];
	}
	self.remainderBinding = [RACKVOBinding bindingWithTarget:remainderTarget keyPath:self.remainder];
}

- (void)dispose {
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

@end

@implementation NSObject (RACKVOBinding)

- (NSMutableSet *)RACKVOBindings {
	return objc_getAssociatedObject(self, RACKVOBindingsKey);
}

- (void)setRACKVOBindings:(NSMutableSet *)RACKVOBindings {
	objc_setAssociatedObject(self, RACKVOBindingsKey, RACKVOBindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)rac_addBinding:(RACKVOBinding *)binding {
	prepareClassForBindingIfNeeded([self class]);
	@synchronized(self) {
		if (!self.RACKVOBindings) self.RACKVOBindings = [NSMutableSet set];
		[self.RACKVOBindings addObject:binding];
	}
}

- (void)rac_removeBinding:(RACKVOBinding *)binding {
	@synchronized(self) {
		[self.RACKVOBindings removeObject:binding];
	}
}

- (void)rac_customWillChangeValueForKey:(NSString *)key {
	NSSet *bindings = nil;
	@synchronized(self) {
		bindings = [self.RACKVOBindings copy];
	}
	for (RACKVOBinding *binding in bindings) {
    if (binding.target == self && [binding.key isEqualToString:key]) {
			[binding targetWillChangeValue];
		}
	}
	[self rac_customWillChangeValueForKey:key];
}

- (void)rac_customDidChangeValueForKey:(NSString *)key {
	NSSet *bindings = nil;
	@synchronized(self) {
		bindings = [self.RACKVOBindings copy];
	}
	for (RACKVOBinding *binding in bindings) {
    if (binding.target == self && [binding.key isEqualToString:key]) {
			[binding targetDidChangeValue];
		}
	}
	[self rac_customDidChangeValueForKey:key];
}

@end

@implementation RACKVOProperty

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
	RACKVOProperty *property = [[self alloc] init];
	if (property == nil) return nil;
	
	property->_target = target;
	property->_keyPath = [keyPath copy];
	@weakify(property);
	property->_exposedSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(property);
		[subscriber sendNext:[property.target valueForKeyPath:keyPath]];
		return [[property.target rac_signalForKeyPath:property.keyPath onObject:property] subscribe:subscriber];
	}];
	property->_exposedSubscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(property);
		[property.target setValue:x forKeyPath:property.keyPath];
	} error:^(NSError *error) {
		@strongify(property);
		NSAssert(NO, @"Received error in RACKVOProperty for key path \"%@\" on %@: %@", property.keyPath, property.target, error);
		
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in binding for key path \"%@\" on %@: %@", property.keyPath, property.target, error);
	} completed:nil];
	
	return property;
}

- (RACBinding *)binding {
	return [RACKVOBinding bindingWithTarget:self.target keyPath:self.keyPath];
}

- (id)objectForKeyedSubscript:(id)key {
	return [self valueForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(id)key {
	[[self valueForKey:key] bindTo:obj];
}

@end
