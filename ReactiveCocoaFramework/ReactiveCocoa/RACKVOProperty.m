//
//  RACKVOProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 27/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACKVOProperty.h"
#import "RACDisposable.h"
#import "RACSubject.h"
#import "RACSwizzling.h"
#import "RACTuple.h"
#import "NSObject+RACKVOWrapper.h"
#import "NSObject+RACPropertySubscribing.h"
#import "EXTScope.h"

static void *RACKVOBindingsKey = &RACKVOBindingsKey;

static NSString * const RACKVOBindingExceptionName = @"RACKVOBinding exception";
static NSString * const RACKVOBindingExceptionBindingKey = @"RACKVOBindingExceptionBindingKey";

@interface RACKVOBinding : RACBinding {
@protected
	RACSignal *(^_signalBlock)(void);
	RACSubject *_signalSubject;
	RACSubject *_subscriberSubject;
}

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath;

- (instancetype)initWithTarget:(id)target key:(NSString *)key;

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly, copy) NSString *key;
@property (nonatomic, readonly, copy) RACSignal *(^signalBlock)(void);
@property (nonatomic, readonly, strong) RACSubject *signalSubject;
@property (nonatomic, readonly, strong) RACSubject *subscriberSubject;
@property (nonatomic, readonly, strong) id observer;
@property (nonatomic, getter = isDisposed) BOOL disposed;

- (void)targetWillChangeValue;
- (void)targetDidChangeValue;
- (void)dispose;

@end

@interface RACKeyKVOBinding : RACKVOBinding

@end

@interface RACRemainderKVOBinding : RACKVOBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key remainder:(NSString *)remainder;

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

@implementation RACKVOBinding

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	if (self.signalBlock != nil) return [self.signalBlock() subscribe:subscriber];
	return [self.signalSubject subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.subscriberSubject sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.subscriberSubject sendError:error];
}

- (void)sendCompleted {
	[self.subscriberSubject sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.subscriberSubject didSubscribeWithDisposable:disposable];
}

#pragma mark API
+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath {
	NSRange firstDot = [keyPath rangeOfString:@"."];
	if (firstDot.location == NSNotFound) {
		return [[RACKeyKVOBinding alloc] initWithTarget:target key:keyPath];
	} else {
		NSString *key = [keyPath substringToIndex:firstDot.location];
		NSString *remainder = [keyPath substringFromIndex:NSMaxRange(firstDot)];
		return [[RACRemainderKVOBinding alloc] initWithTarget:target key:key remainder:remainder];
	}
}

- (instancetype)initWithTarget:(id)target key:(NSString *)key {
	self = [super init];
	if (self == nil || target == nil || key == nil) return nil;
	_target = target;
	_key = [key copy];
	_signalSubject = [RACSubject subject];
	_subscriberSubject = [RACSubject subject];
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
		[self.signalSubject sendCompleted];
		[self.subscriberSubject sendCompleted];
		[self.target rac_removeObserverWithIdentifier:self.observer];
		[self.target rac_removeBinding:self];
	}
}

@end

@interface RACKeyKVOBinding ()

@property (nonatomic) NSUInteger stackDepth;
@property (nonatomic) BOOL ignoreNextUpdate;

@end

@implementation RACKeyKVOBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key {
	self = [super initWithTarget:target key:key];
	if (self == nil) return nil;
	@weakify(self);
	_signalBlock = [^{
		return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			@strongify(self);
			[subscriber sendNext:[self.target valueForKey:self.key]];
			return [self.signalSubject subscribe:subscriber];
		}];
	} copy];
	[_subscriberSubject subscribeNext:^(id x) {
		@strongify(self);
		self.ignoreNextUpdate = YES;
		[self.target setValue:x forKey:self.key];
	}];
	return self;
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
	[self.signalSubject sendNext:value];
}

@end

@interface RACRemainderKVOBinding ()

@property (nonatomic, readonly, copy) NSString *remainder;
@property (nonatomic, strong) RACKVOBinding *remainderBinding;

@end

@implementation RACRemainderKVOBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key remainder:(NSString *)remainder {
	self = [super initWithTarget:target key:key];
	if (self == nil || remainder == nil) return nil;
	_remainder = remainder;
	_remainderBinding = [RACKVOBinding bindingWithTarget:[target valueForKey:key] keyPath:remainder];
	@weakify(self);
	[_remainderBinding subscribeNext:^(id x) {
		@strongify(self);
		[self.signalSubject sendNext:x];
	}];
	_signalBlock = [^{
		return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
			@strongify(self);
			[subscriber sendNext:[[self.target valueForKey:key] valueForKeyPath:remainder]];
			return [self.signalSubject subscribe:subscriber];
		}];
	} copy];
	[_subscriberSubject subscribeNext:^(id x) {
		@strongify(self);
		[self.remainderBinding.subscriberSubject sendNext:x];
	}];
	return self;
}

- (void)targetWillChangeValue {
	[self.remainderBinding dispose];
}

- (void)targetDidChangeValue {
	id remainderTarget = [self.target valueForKey:self.key];
	if (remainderTarget == nil) {
		self.remainderBinding = nil;
		[self.signalSubject sendNext:nil];
	}
	self.remainderBinding = [RACKVOBinding bindingWithTarget:remainderTarget keyPath:self.remainder];
	@weakify(self);
	[self.remainderBinding subscribeNext:^(id x) {
		@strongify(self);
		[self.signalSubject sendNext:x];
	}];
}

- (void)dispose {
	@synchronized(self) {
		if (self.disposed) return;
		[super dispose];
		[self.remainderBinding dispose];
	}
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

@interface RACKVOProperty ()

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly, copy) NSString *keyPath;
@property (nonatomic, readonly, strong) RACSignal *signal;
@property (nonatomic, readonly, strong) id<RACSubscriber> subscriber;

@end

@implementation RACKVOProperty

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.signal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.subscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.subscriber sendError:error];
}

- (void)sendCompleted {
	[self.subscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.subscriber didSubscribeWithDisposable:disposable];
}

#pragma mark API

+ (instancetype)propertyWithTarget:(id)target keyPath:(NSString *)keyPath {
	RACKVOProperty *property = [[self alloc] init];
	if (property == nil) return nil;
	property->_target = target;
	property->_keyPath = [keyPath copy];
	@weakify(property);
	property->_signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		@strongify(property);
		[subscriber sendNext:[property.target valueForKeyPath:keyPath]];
		return [[property.target rac_signalForKeyPath:property.keyPath onObject:property] subscribe:subscriber];
	}];
	property->_subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(property);
		[property.target setValue:x forKeyPath:property.keyPath];
	} error:nil completed:nil];
	return property;
}

- (RACBinding *)binding {
	return [RACKVOBinding bindingWithTarget:self.target keyPath:self.keyPath];
}

- (id)objectForKeyedSubscript:(id)key {
	return [self binding];
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
	[[self binding] bindTo:obj];
}

@end

@implementation NSObject (RACKVOProperty)

- (RACProperty *)rac_propertyForKeyPath:(NSString *)keyPath {
	return [RACKVOProperty propertyWithTarget:self keyPath:keyPath];
}

@end
