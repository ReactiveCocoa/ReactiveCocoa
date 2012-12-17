//
//  RACBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACSubject.h"
#import "RACDisposable.h"
#import "RACSwizzling.h"
#import "NSObject+RACPropertySubscribing.h"

static void *RACBindingsKey = &RACBindingsKey;

static NSString * const RACBindingExceptionName = @"RACBinding exception";
static NSString * const RACBindingExceptionBindingKey = @"RACBindingExceptionBindingKey";

@interface RACBinding : RACDisposable

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath parentBinding:(RACBinding *)parentBinding;

- (instancetype)initWithTarget:(id)target key:(NSString *)key parentBinding:(RACBinding *)parentBinding;

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly, copy) NSString *key;
@property (nonatomic, readonly, weak) RACBinding *parentBinding;
@property (nonatomic, readonly, getter = isDisposed) BOOL disposed;

- (void)targetWillChangeValue;
- (void)targetDidChangeValue;

- (void)sendBindingValue:(id)value sender:(id)sender;

@end

@interface RACRootBinding : RACBinding

- (instancetype)initWithSource:(RACBindingPoint *)source destination:(RACBindingPoint *)destination;

@end

@interface RACKeyBinding : RACBinding

@end

@interface RACRemainderBinding : RACBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key remainder:(NSString *)remainder parentBinding:(RACBinding *)parentBinding;

@end

@interface NSObject (RACBindings_Private)

@property (nonatomic, strong) NSMutableSet *RACBindings;
- (void)rac_addBinding:(RACBinding *)binding;
- (void)rac_removeBinding:(RACBinding *)binding;
- (void)rac_customWillChangeValueForKey:(NSString *)key;
- (void)rac_customDidChangeValueForKey:(NSString *)key;

@end

@interface RACKeyPathBindingPoint : RACBindingPoint

@property (atomic, readonly, strong) id target;
@property (atomic, readonly, copy) NSString *keyPath;

- (instancetype)initWithTarget:(id)target keyPath:(NSString *)keyPath;

@end

@interface RACTransformerBindingPoint : RACBindingPoint

@property (atomic, readonly, copy) RACBindingPoint *target;
@property (atomic, readonly, copy) RACTuple *(^transformer)(RACTuple *);

- (instancetype)initWithTarget:(RACBindingPoint *)target transformer:(RACTuple *(^)(RACTuple *))transformer;

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

@interface RACBinding ()

@property (nonatomic, readonly, strong) id observer;
@property (nonatomic, getter = isDisposed) BOOL disposed;

@end

@implementation RACBinding

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath parentBinding:(RACBinding *)parentBinding {
	NSRange firstDot = [keyPath rangeOfString:@"."];
	if (firstDot.location == NSNotFound) {
		return [[RACKeyBinding alloc] initWithTarget:target key:keyPath parentBinding:parentBinding];
	} else {
		NSString *key = [keyPath substringToIndex:firstDot.location];
		NSString *remainder = [keyPath substringFromIndex:NSMaxRange(firstDot)];
		return [[RACRemainderBinding alloc] initWithTarget:target key:key remainder:remainder parentBinding:parentBinding];
	}
}

- (instancetype)initWithTarget:(id)target key:(NSString *)key parentBinding:(RACBinding *)parentBinding {
	self = [super init];
	if (self == nil || target == nil || key == nil) return nil;
	_target = target;
	_key = [key copy];
	_parentBinding = parentBinding;
	prepareClassForBindingIfNeeded([_target class]);
	[_target rac_addBinding:self];
	_observer = [_target rac_addObserver:self forKeyPath:key options:NSKeyValueObservingOptionPrior queue:nil block:nil];
	[_target rac_addDeallocDisposable:self];
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
		[self.target rac_removeObserverWithIdentifier:self.observer];
		[self.target rac_removeBinding:self];
	}
}

@end

@interface RACRootBinding ()

@property (nonatomic, strong) id receiverBinding;
@property (nonatomic, strong) id otherBinding;

@end

@implementation RACRootBinding

- (instancetype)initWithSource:(RACBindingPoint *)source destination:(RACBindingPoint *)destination {
	
	return self;
}

- (void)sendBindingValue:(id)value sender:(id)sender {
	if ([sender isEqual:self.receiverBinding]) {
		[self.otherBinding sendBindingValue:value sender:self];
	} else if ([sender isEqual:self.otherBinding]) {
		[self.receiverBinding sendBindingValue:value sender:self];
	}
}

- (void)dispose {
	@synchronized(self) {
		if (self.disposed) return;
		[super dispose];
		[self.receiverBinding dispose];
		[self.otherBinding dispose];
	}
}

@end

@interface RACKeyBinding ()

@property (nonatomic) NSUInteger stackDepth;
@property (nonatomic) BOOL ignoreNextUpdate;

@end

@implementation RACKeyBinding

- (void)targetWillChangeValue {
	++self.stackDepth;
}

- (void)targetDidChangeValue {
	--self.stackDepth;
	if (self.stackDepth == NSUIntegerMax) @throw [NSException exceptionWithName:RACBindingExceptionName reason:@"Receiver called -didChangeValueForKey: without corresponding -willChangeValueForKey:" userInfo:@{ RACBindingExceptionBindingKey : self }];
	if (self.stackDepth != 0) return;
	if (self.ignoreNextUpdate) {
		self.ignoreNextUpdate = NO;
		return;
	}
	id value = [self.target valueForKey:self.key];
	[self.parentBinding sendBindingValue:value sender:self];
}

- (void)sendBindingValue:(id)value sender:(id)sender {
	if (sender != self.parentBinding) return;
	self.ignoreNextUpdate = YES;
	@synchronized(self) {
		if (self.disposed) return;
		[self.target setValue:value forKeyPath:self.key];
	}
}

@end

@interface RACRemainderBinding ()

@property (nonatomic, readonly, copy) NSString *remainder;
@property (nonatomic, strong) RACBinding *remainderBinding;

@end

@implementation RACRemainderBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key remainder:(NSString *)remainder parentBinding:(RACBinding *)parentBinding {
	self = [super initWithTarget:target key:key parentBinding:parentBinding];
	if (self == nil || remainder == nil) return nil;
	
	_remainder = remainder;
	id remainderTarget = [target valueForKey:key];
	self.remainderBinding = [RACBinding bindingWithTarget:remainderTarget keyPath:remainder parentBinding:self];
	
	return self;
}

- (void)targetWillChangeValue {
	[self.remainderBinding dispose];
}

- (void)targetDidChangeValue {
	id remainderTarget = [self.target valueForKey:self.key];
	id value = [remainderTarget valueForKeyPath:self.remainder];
	self.remainderBinding = [RACBinding bindingWithTarget:remainderTarget keyPath:self.remainder parentBinding:self];
	[self.parentBinding sendBindingValue:value sender:self];
}

- (void)sendBindingValue:(id)value sender:(id)sender {
	if (sender == self.remainderBinding) {
		[self.parentBinding sendBindingValue:value sender:self];
	} else if (sender == self.parentBinding) {
		[self.remainderBinding sendBindingValue:value sender:self];
	}
}

- (void)dispose {
	@synchronized(self) {
		if (self.disposed) return;
		[super dispose];
		[self.remainderBinding dispose];
	}
}

@end

@implementation NSObject (RACBindings_Private)

- (NSMutableSet *)RACBindings {
	return objc_getAssociatedObject(self, RACBindingsKey);
}

- (void)setRACBindings:(NSMutableSet *)RACBindings {
	objc_setAssociatedObject(self, RACBindingsKey, RACBindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)rac_addBinding:(RACBinding *)binding {
	prepareClassForBindingIfNeeded([self class]);
	@synchronized(self) {
		if (!self.RACBindings) self.RACBindings = [NSMutableSet set];
		[self.RACBindings addObject:binding];
	}
}

- (void)rac_removeBinding:(RACBinding *)binding {
	@synchronized(self) {
		[self.RACBindings removeObject:binding];
	}
}

- (void)rac_customWillChangeValueForKey:(NSString *)key {
	NSSet *bindings = nil;
	@synchronized(self) {
		bindings = [self.RACBindings copy];
	}
	for (RACBinding *binding in bindings) {
    if (binding.target == self && [binding.key isEqualToString:key]) {
			[binding targetWillChangeValue];
		}
	}
	[self rac_customWillChangeValueForKey:key];
}

- (void)rac_customDidChangeValueForKey:(NSString *)key {
	NSSet *bindings = nil;
	@synchronized(self) {
		bindings = [self.RACBindings copy];
	}
	for (RACBinding *binding in bindings) {
    if (binding.target == self && [binding.key isEqualToString:key]) {
			[binding targetDidChangeValue];
		}
	}
	[self rac_customDidChangeValueForKey:key];
}

@end

@implementation RACBindingPoint

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return self;
}

#pragma mark NSDictionary

- (id)objectForKeyedSubscript:(id)key {
	return self;
}

#pragma mark NSMutableDictionary

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key {
	[self bindWithOtherPoint:obj];
}

#pragma mark API

+ (instancetype)bindingPointFor:(id)target keyPath:(NSString *)keyPath {
	return [[RACKeyPathBindingPoint alloc] initWithTarget:target keyPath:keyPath];
}

- (instancetype)bindingPointByTransformingSignals:(RACTuple *(^)(RACTuple *))signalsTransformer {
	return [[RACTransformerBindingPoint alloc] initWithTarget:self transformer:signalsTransformer];
}

- (RACDisposable *)bindWithOtherPoint:(RACBindingPoint *)bindingPoint {
	return [[RACRootBinding alloc] initWithSource:self destination:bindingPoint];
}

@end

@implementation RACKeyPathBindingPoint

- (instancetype)initWithTarget:(id)target keyPath:(NSString *)keyPath {
	self = [super init];
	if (self == nil || target == nil || keyPath == nil) return nil;
	_target = target;
	_keyPath = [keyPath copy];
	return self;
}

@end

@implementation RACTransformerBindingPoint

- (instancetype)initWithTarget:(RACBindingPoint *)target transformer:(RACTuple *(^)(RACTuple *))transformer {
	self = [super init];
	if (self == nil || target == nil || transformer == nil) return nil;
	_target = [target copy];
	_transformer = [transformer copy];
	return self;
}

@end

@implementation NSObject (RACBinding)

- (RACBindingPoint *)rac_bindingPointForKeyPath:(NSString *)keyPath {
	return [RACBindingPoint bindingPointFor:self keyPath:keyPath];
}

@end
