//
//  RACKVOProxy.m
//  ReactiveCocoa
//
//  Created by Richard Speyer on 4/10/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACKVOProxy.h"

@interface WeakObjectHolder : NSObject
@property(weak, nonatomic) id object;
@end

@implementation WeakObjectHolder
+ (WeakObjectHolder *)holderWithObject:(id)object {
	WeakObjectHolder *holder = [[[self class] alloc] init];
	holder.object = object;
	return holder;
}

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@:%p object: %@>",
			NSStringFromClass([self class]),
			(__bridge void *) self,
			self.object];
}
@end

@interface RACMapTable : NSObject
- (id)objectForKey:(id)aKey;

- (void)removeObjectForKey:(id)aKey;
- (void)setObject:(id)anObject forKey:(id)aKey;
@end

@implementation RACMapTable {
	NSMapTable *m_mapTable;
	NSMutableDictionary *m_dictionary;
}

- (instancetype)init {
	self = [super init];
	if (self == nil) return nil;
	if ([NSMapTable class]) {
		m_mapTable = [NSMapTable strongToStrongObjectsMapTable];
	}
	else {
		m_dictionary = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (id)objectForKey:(id)aKey {
	if (m_mapTable) {
		return [m_mapTable objectForKey:aKey];
	}
	else {
		WeakObjectHolder *holder = [m_dictionary objectForKey:aKey];
		return holder.object;
	}
}

- (void)removeObjectForKey:(id)aKey {
	if (m_mapTable) {
		[m_mapTable removeObjectForKey:aKey];
	}
	else {
		[m_dictionary removeObjectForKey:aKey];
	}
}

- (void)setObject:(id)anObject forKey:(id)aKey {
	if (m_mapTable) {
		[m_mapTable setObject:anObject forKey:aKey];
	}
	else {
		WeakObjectHolder *holder = [WeakObjectHolder holderWithObject:anObject];
		[m_dictionary setObject:holder forKey:aKey];
	}
}

@end

@interface RACKVOProxy()
@property(strong, nonatomic, readonly) RACMapTable *trampolines;
@end

@implementation RACKVOProxy

+ (RACKVOProxy *)instance {
    static RACKVOProxy *proxy;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        proxy = [[RACKVOProxy alloc] init];
    });
    
    return proxy;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) return nil;
    _trampolines = [[RACMapTable alloc] init];
    return self;
}

- (void)addObserver:(NSObject *)observer forContext:(void *)context {
    NSValue *valueContext = [NSValue valueWithPointer:context];
    @synchronized (self) {
        [self.trampolines setObject:observer forKey:valueContext];
    }
}

- (void)removeObserver:(NSObject *)observer forContext:(void *)context {
    NSValue *valueContext = [NSValue valueWithPointer:context];
    @synchronized (self) {
        [self.trampolines removeObjectForKey:valueContext];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSValue *valueContext = [NSValue valueWithPointer:context];
    NSObject *trueObserver;
    @synchronized (self) {
        trueObserver = [self.trampolines objectForKey:valueContext];
    }
    if (trueObserver) {
        [trueObserver observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    else {
        NSLog(@"observer of \"%@\" on %@ is gone", keyPath, object);
    }
}

@end
