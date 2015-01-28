//
//  RACKVOProxy.m
//  ReactiveCocoa
//
//  Created by Richard Speyer on 4/10/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACKVOProxy.h"

@interface RACKVOProxy()

@property (strong, nonatomic, readonly) NSMapTable *trampolines;
@property (strong, nonatomic, readonly) dispatch_queue_t queue;

@end

@implementation RACKVOProxy

+ (instancetype)sharedProxy {
	static RACKVOProxy *proxy;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		proxy = [[self alloc] init];
	});

	return proxy;
}

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;

	_queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.RACKVOProxy", DISPATCH_QUEUE_SERIAL);
	_trampolines = [NSMapTable strongToWeakObjectsMapTable];

	return self;
}

- (void)addObserver:(__weak NSObject *)observer forContext:(void *)context {
	NSValue *valueContext = [NSValue valueWithPointer:context];

	dispatch_sync(self.queue, ^{
		[self.trampolines setObject:observer forKey:valueContext];
	});
}

- (void)removeObserver:(NSObject *)observer forContext:(void *)context {
	NSValue *valueContext = [NSValue valueWithPointer:context];

	dispatch_sync(self.queue, ^{
		[self.trampolines removeObjectForKey:valueContext];
	});
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	NSValue *valueContext = [NSValue valueWithPointer:context];
	__block NSObject *trueObserver;

	dispatch_sync(self.queue, ^{
		trueObserver = [self.trampolines objectForKey:valueContext];
	});

	if (trueObserver != nil) {
		[trueObserver observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

@end
