//
//  RACKVOProxy.m
//  ReactiveCocoa
//
//  Created by Richard Speyer on 4/10/14.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "RACKVOProxy.h"

@interface RACKVOProxy()
@property(strong, nonatomic, readonly) NSMapTable *trampolines;
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
    _trampolines = [NSMapTable strongToWeakObjectsMapTable];
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
