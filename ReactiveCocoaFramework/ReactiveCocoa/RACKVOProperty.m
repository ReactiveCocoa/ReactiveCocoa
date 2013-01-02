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

// Name of exceptions thrown by RACKVOBinding
static NSString * const RACKVOBindingExceptionName = @"RACKVOBinding exception";
// Name of the key associated with the instance that threw the exception in the
// userInfo dictionary in exceptions thrown by RACKVOBinding, if applicable.
static NSString * const RACKVOBindingExceptionBindingKey = @"RACKVOBindingExceptionBindingKey";

@interface RACKVOProperty ()

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly, copy) NSString *keyPath;
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;
@property (nonatomic, readonly, strong) id<RACSubscriber> exposedSubscriber;

@end

@interface RACKVOBinding : RACBinding

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath;

- (instancetype)initWithTarget:(id)target key:(NSString *)key exposedSignal:(RACSignal *)exposedSignal;

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly, copy) NSString *key;
@property (nonatomic, readonly, strong) RACSignal *exposedSignal;
@property (nonatomic, readonly, strong) RACSubject *exposedSignalSubject;
@property (nonatomic, readonly, strong) RACSubject *exposedSubscriberSubject;
@property (nonatomic, readonly, strong) id observer;
@property (nonatomic, getter = isDisposed) BOOL disposed;

- (void)targetWillChangeValue;
- (void)targetDidChangeValue;
- (void)dispose;

@end

@interface RACKeyKVOBinding : RACKVOBinding

@property (nonatomic) NSUInteger stackDepth;
@property (nonatomic) BOOL ignoreNextUpdate;

@end

@interface RACRemainderKVOBinding : RACKVOBinding

@property (nonatomic, readonly, copy) NSString *remainder;
@property (nonatomic, strong) RACKVOBinding *remainderBinding;

@end

@interface NSObject (RACKVOBinding)

@property (nonatomic, strong) NSMutableSet *RACKVOBindings;
- (void)rac_addBinding:(RACKVOBinding *)binding;
- (void)rac_removeBinding:(RACKVOBinding *)binding;
- (void)rac_customWillChangeValueForKey:(NSString *)key;
- (void)rac_customDidChangeValueForKey:(NSString *)key;

@end

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
