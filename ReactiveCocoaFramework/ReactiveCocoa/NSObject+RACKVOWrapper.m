//
//  NSObject+RACKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+RACKVOWrapper.h"
#import "RACSwizzling.h"
#import <objc/runtime.h>

typedef void (^RACKVOBlock)(id, NSDictionary *);

static void *RACKVOTrampolinesKey = &RACKVOTrampolinesKey;
static void *RACKVOWrapperContext = &RACKVOWrapperContext;

static NSMutableSet *swizzledClasses() {
	static dispatch_once_t onceToken;
	static NSMutableSet *swizzledClasses = nil;
	dispatch_once(&onceToken, ^{
		swizzledClasses = [[NSMutableSet alloc] init];
	});
	
	return swizzledClasses;
}

@interface NSObject ()
// This set should only be manipulated while synchronized on the receiver.
@property (nonatomic, strong) NSMutableSet *RACKVOTrampolines;
@end

@interface RACKVOTrampoline : NSObject

- (id)initWithTarget:(NSObject *)target observer:(NSObject *)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(RACKVOBlock)block;

@property (nonatomic, readonly, copy) NSString *keyPath;
@property (nonatomic, readonly, strong) NSOperationQueue *queue;

// These properties should only be manipulated while synchronized on the
// receiver.
@property (nonatomic, copy) RACKVOBlock block;
@property (nonatomic, unsafe_unretained) NSObject *target;
@property (nonatomic, unsafe_unretained) NSObject *observer;

- (void)addAsTrampolineOnObject:(NSObject *)obj;

@end

@implementation RACKVOTrampoline

#pragma mark Lifecycle

- (id)initWithTarget:(NSObject *)target observer:(NSObject *)observer keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(RACKVOBlock)block {
	self = [super init];
	if (self == nil) return nil;

	_keyPath = [keyPath copy];
	_queue = queue;

	self.block = block;
	self.target = target;
	self.observer = observer;

	[self.target addObserver:self forKeyPath:self.keyPath options:options context:&RACKVOWrapperContext];
	[self addAsTrampolineOnObject:self.target];
	[self addAsTrampolineOnObject:self.observer];

	return self;
}

- (void)addAsTrampolineOnObject:(NSObject *)obj {
	@synchronized (obj) {
		if (obj.RACKVOTrampolines == nil) {
			obj.RACKVOTrampolines = [NSMutableSet setWithObject:self];
		} else {
			[obj.RACKVOTrampolines addObject:self];
		}
	}
}

- (void)dealloc {
	[self stopObserving];
}

#pragma mark Observation

- (void)stopObserving {
	NSObject *target;
	NSObject *observer;

	@synchronized (self) {
		self.block = nil;
		
		target = self.target;
		observer = self.observer;

		self.target = nil;
		self.observer = nil;
	}

	@synchronized (target) {
		[target.RACKVOTrampolines removeObject:self];
	}

	@synchronized (observer) {
		[observer.RACKVOTrampolines removeObject:self];
	}

	[target removeObserver:self forKeyPath:self.keyPath];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (context != &RACKVOWrapperContext) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}

	RACKVOBlock block;
	id observer;
	// We need to keep the target alive until the notification's been delivered,
	// which could be some point later in time if we're not in `queue` currently.
	__block id target;

	@synchronized (self) {
		block = self.block;
		observer = self.observer;
		target = self.target;
	}

	void (^notificationBlock)(void) = ^{
		if (block != nil) block(observer, change);
	};

	if (self.queue == nil || self.queue == [NSOperationQueue currentQueue]) {
		notificationBlock();
	} else {
		[self.queue addOperationWithBlock:^{
			notificationBlock();
			target = nil;
		}];
	}
}

@end

@implementation NSObject (RACKVOWrapper)

- (void)rac_customDealloc {
	NSSet *trampolines;
	
	@synchronized (self) {
		trampolines = [self.RACKVOTrampolines copy];
		self.RACKVOTrampolines = nil;
	}

	// If we're currently delivering a KVO callback then niling the trampoline set might not dealloc the trampoline and therefore make them be dealloc'd. So we need to manually stop observing on all of them as well.
	[trampolines makeObjectsPerformSelector:@selector(stopObserving)];

	[self rac_customDealloc];
}

- (id)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(void (^)(id observer, NSDictionary *change))block {
	void (^swizzle)(Class) = ^(Class classToSwizzle){
		NSString *className = NSStringFromClass(classToSwizzle);
		if ([swizzledClasses() containsObject:className]) return;

		RACSwizzle(classToSwizzle, NSSelectorFromString(@"dealloc"), @selector(rac_customDealloc));
		[swizzledClasses() addObject:className];
	};

	// We swizzle the dealloc for both the object being observed and the observer of the observation. Because when either gets dealloc'd, we need to tear down the observation.
	@synchronized (swizzledClasses()) {
		swizzle(self.class);
		swizzle(observer.class);
	}
	
	return [[RACKVOTrampoline alloc] initWithTarget:self observer:observer keyPath:keyPath options:options queue:queue block:block];
}

- (BOOL)rac_removeObserverWithIdentifier:(RACKVOTrampoline *)trampoline {
	if (trampoline.target != self) return NO;
	
	[trampoline stopObserving];
	return YES;
}

- (NSMutableSet *)RACKVOTrampolines {
	return objc_getAssociatedObject(self, RACKVOTrampolinesKey);
}

- (void)setRACKVOTrampolines:(NSMutableSet *)set {
	objc_setAssociatedObject(self, RACKVOTrampolinesKey, set, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
