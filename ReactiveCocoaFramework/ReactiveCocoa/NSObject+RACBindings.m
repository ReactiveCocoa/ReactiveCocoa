//
//  NSObject+RACBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACBindings.h"
#import "RACSignal.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACSubject.h"
#import "RACDisposable.h"
#import "RACScheduler.h"
#import "RACSwizzling.h"
#import "NSObject+RACPropertySubscribing.h"

static void *RACBindingsKey = &RACBindingsKey;

static NSString * const RACBindingExceptionName = @"RACBinding exception";
static NSString * const RACBindingExceptionBindingKey = @"RACBindingExceptionBindingKey";

@interface RACBinding : RACDisposable

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath transformer:(id(^)(id))transformer parentBinding:(RACBinding *)parentBinding;

- (instancetype)initWithTarget:(id)target key:(NSString *)key transformer:(id(^)(id))transformer parentBinding:(RACBinding *)parentBinding;

@property (nonatomic, readonly, weak) id target;
@property (nonatomic, readonly, copy) NSString *key;
@property (nonatomic, readonly, copy) id(^transformer)(id);
@property (nonatomic, readonly, weak) RACBinding *parentBinding;
@property (nonatomic, readonly, getter = isDisposed) BOOL disposed;

- (void)targetWillChangeValue;
- (void)targetDidChangeValue;

- (NSUInteger)addAndFetchBindingVersion;
- (void)setBindingValue:(id)value withVersion:(NSUInteger)version sender:(id)sender;

@end

@interface RACRootBinding : RACBinding

- (instancetype)initWithReceiver:(id)receiver receiverKeyPath:(NSString *)receiverKeyPath receiverTransformer:(id(^)(id))receiverTransformer receiverScheduler:(RACScheduler *)receiverScheduler otherObject:(id)otherObject otherKeyPath:(NSString *)otherKeyPath otherTransformer:(id(^)(id))otherTransformer otherScheduler:(RACScheduler *)otherScheduler;

@end

@interface RACKeyBinding : RACBinding

@end

@interface RACRemainderBinding : RACBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key remainder:(NSString *)remainder transformer:(id(^)(id))transformer parentBinding:(RACBinding *)parentBinding;

@end

@interface NSObject (RACBindings_Private)

@property (nonatomic, strong) NSMutableSet *RACBindings;
- (void)rac_addBinding:(RACBinding *)binding;
- (void)rac_removeBinding:(RACBinding *)binding;
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

@interface RACBinding ()

@property (nonatomic, readonly, strong) id observer;
@property (nonatomic) BOOL disposed;

@end

@implementation RACBinding

+ (instancetype)bindingWithTarget:(id)target keyPath:(NSString *)keyPath transformer:(id (^)(id))transformer parentBinding:(RACBinding *)parentBinding {
	NSRange firstDot = [keyPath rangeOfString:@"."];
	if (firstDot.location == NSNotFound) {
		return [[RACKeyBinding alloc] initWithTarget:target key:keyPath transformer:transformer parentBinding:parentBinding];
	} else {
		NSString *key = [keyPath substringToIndex:firstDot.location];
		NSString *remainder = [keyPath substringFromIndex:NSMaxRange(firstDot)];
		return [[RACRemainderBinding alloc] initWithTarget:target key:key remainder:remainder transformer:transformer parentBinding:parentBinding];
	}
}

- (instancetype)initWithTarget:(id)target key:(NSString *)key transformer:(id (^)(id))transformer parentBinding:(RACBinding *)parentBinding {
	self = [super init];
	if (self == nil || target == nil || key == nil) return nil;
	_target = target;
	_key = [key copy];
	_transformer = [transformer copy];
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

- (NSUInteger)addAndFetchBindingVersion {
	return [self.parentBinding addAndFetchBindingVersion];
}

- (void)setBindingValue:(id)value withVersion:(NSUInteger)version sender:(id)sender {
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

@property (nonatomic, readonly, strong) RACScheduler *receiverScheduler;
@property (nonatomic, readonly, strong) RACScheduler *otherScheduler;
@property (nonatomic, strong) id receiverBinding;
@property (nonatomic, strong) id otherBinding;
@property (nonatomic, getter = isDisposed) BOOL disposed;

@end

@implementation RACRootBinding {
	volatile NSUInteger _bindingVersion;
}

- (instancetype)initWithReceiver:(id)receiver receiverKeyPath:(NSString *)receiverKeyPath receiverTransformer:(id (^)(id))receiverTransformer receiverScheduler:(RACScheduler *)receiverScheduler otherObject:(id)otherObject otherKeyPath:(NSString *)otherKeyPath otherTransformer:(id (^)(id))otherTransformer otherScheduler:(RACScheduler *)otherScheduler {
	self = [super init];
	if (!self) return nil;
	
	_receiverScheduler = receiverScheduler ?: [RACScheduler immediateScheduler];
	_otherScheduler = otherScheduler ?: [RACScheduler immediateScheduler];
	receiverKeyPath = [receiverKeyPath copy];
	otherKeyPath = [otherKeyPath copy];
	receiverTransformer = [receiverTransformer copy];
	otherTransformer = [otherTransformer copy];
	
	[_otherScheduler schedule:^{
		id value = [otherObject valueForKeyPath:otherKeyPath];
		if (otherTransformer) value = otherTransformer(value);
		[self.receiverScheduler schedule:^{
			@synchronized(self) {
				if (self.disposed) return;
				[receiver setValue:value forKeyPath:receiverKeyPath];
				self.receiverBinding = [RACBinding bindingWithTarget:receiver keyPath:receiverKeyPath transformer:receiverTransformer parentBinding:self];
			}
		}];
		@synchronized(self) {
			if (self.disposed) return;
			self.otherBinding = [RACBinding bindingWithTarget:otherObject keyPath:otherKeyPath transformer:otherTransformer parentBinding:self];
		}
	}];
	
	return self;
}

- (NSUInteger)addAndFetchBindingVersion {
	return __sync_add_and_fetch(&_bindingVersion, 1);
}

- (void)setBindingValue:(id)value withVersion:(NSUInteger)version sender:(id)sender {
	if ([sender isEqual:self.receiverBinding]) {
		[self.otherScheduler schedule:^{
			[self.otherBinding setBindingValue:value withVersion:version sender:self];
		}];
	} else if ([sender isEqual:self.otherBinding]) {
		[self.receiverScheduler schedule:^{
			[self.receiverBinding setBindingValue:value withVersion:version sender:self];
		}];
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
@property (nonatomic) NSUInteger targetVersion;
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
	NSUInteger version = [self addAndFetchBindingVersion];
	self.targetVersion = version;
	id value = [self.target valueForKeyPath:self.key];
	if (self.transformer) value = self.transformer(value);
	[self.parentBinding setBindingValue:value withVersion:version sender:self];
}

- (void)setBindingValue:(id)value withVersion:(NSUInteger)version sender:(id)sender {
	if (sender != self.parentBinding || self.targetVersion - version < NSUIntegerMax / 2) return;
	self.ignoreNextUpdate = YES;
	@synchronized(self) {
		if (self.disposed) return;
		self.targetVersion = version;
		[self.target setValue:value forKeyPath:self.key];
	}
}

@end

@interface RACRemainderBinding ()

@property (nonatomic, readonly, copy) NSString *remainder;
@property (nonatomic, strong) RACBinding *remainderBinding;

@end

@implementation RACRemainderBinding

- (instancetype)initWithTarget:(id)target key:(NSString *)key remainder:(NSString *)remainder transformer:(id (^)(id))transformer parentBinding:(RACBinding *)parentBinding {
	self = [super initWithTarget:target key:key transformer:transformer parentBinding:parentBinding];
	if (self == nil || remainder == nil) return nil;
	
	_remainder = remainder;
	id remainderTarget = [target valueForKey:key];
	self.remainderBinding = [RACBinding bindingWithTarget:remainderTarget keyPath:remainder transformer:transformer parentBinding:self];
	
	return self;
}

- (void)targetWillChangeValue {
	[self.remainderBinding dispose];
}

- (void)targetDidChangeValue {
	NSUInteger version = [self addAndFetchBindingVersion];
	id remainderTarget = [self.target valueForKey:self.key];
	id value = [remainderTarget valueForKey:self.remainder];
	if (self.transformer) value = self.transformer(value);
	self.remainderBinding = [RACBinding bindingWithTarget:remainderTarget keyPath:self.remainder transformer:self.transformer parentBinding:self];
	[self.parentBinding setBindingValue:value withVersion:version sender:self];
}

- (void)setBindingValue:(id)value withVersion:(NSUInteger)version sender:(id)sender {
	if (sender == self.remainderBinding) {
		[self.parentBinding setBindingValue:value withVersion:version sender:self];
	} else if (sender == self.parentBinding) {
		[self.remainderBinding setBindingValue:value withVersion:version sender:self];
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

@implementation NSObject (RACBindings)

- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath transformer:(id (^)(id))receiverTransformer onScheduler:(RACScheduler *)receiverScheduler toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath transformer:(id (^)(id))otherTransformer onScheduler:(RACScheduler *)otherScheduler {
	return [[RACRootBinding alloc] initWithReceiver:self receiverKeyPath:receiverKeyPath receiverTransformer:receiverTransformer receiverScheduler:receiverScheduler otherObject:otherObject otherKeyPath:otherKeyPath otherTransformer:otherTransformer otherScheduler:otherScheduler];
}

@end
