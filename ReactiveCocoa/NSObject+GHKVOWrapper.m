//
//  NSObject+GHKVOWrapper.m
//  GitHub
//
//  Created by Josh Abernathy on 10/11/11.
//  Copyright (c) 2011 GitHub. All rights reserved.
//

#import "NSObject+GHKVOWrapper.h"

@class GHKVOTrampoline;


@interface GHKVOTrampoline : NSObject

@property (nonatomic, copy) void (^block)(id blockSelf, NSDictionary *change);
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, unsafe_unretained) NSObject *observer;
@property (nonatomic, unsafe_unretained) NSObject *target;

- (void)startObservingOnObject:(NSObject *)object options:(NSKeyValueObservingOptions)options;
- (void)stopObserving;

@end

@implementation GHKVOTrampoline

static char GHKVOWrapperContext;

- (void)dealloc {
	[self stopObserving];
}

- (void)observeValueForKeyPath:(NSString *)triggeredKeyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(context == &GHKVOWrapperContext) {		
        if(self.queue == nil) {
            self.block(self.observer, change);
            return;
        }
		
		// We want to keep all these guys around until we've delivered the notification block. So this.
		GHKVOTrampoline *capturedSelf = self;
		NSObject *strongTarget = self.target;
        [self.queue addOperationWithBlock:^{
            capturedSelf.block(strongTarget, change);
        }];
    } else {
        [super observeValueForKeyPath:triggeredKeyPath ofObject:object change:change context:context];
    }
}


#pragma mark API

@synthesize block;
@synthesize keyPath;
@synthesize queue;
@synthesize observer;
@synthesize target;

- (void)startObservingOnObject:(NSObject *)object options:(NSKeyValueObservingOptions)options {
	self.observer = object;
	[self.observer addObserver:self forKeyPath:self.keyPath options:options context:&GHKVOWrapperContext];
}

- (void)stopObserving {
	self.target = nil;
	
	[self.observer removeObserver:self forKeyPath:self.keyPath];
	self.observer = nil;
}

@end


@implementation NSObject (GHKVOWrapper)

- (id)addObserver:(NSObject *)target forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options queue:(NSOperationQueue *)queue block:(void (^)(id target, NSDictionary *change))block {
	GHKVOTrampoline *trampoline = [[GHKVOTrampoline alloc] init];
	trampoline.block = block;
	trampoline.keyPath = keyPath;
	trampoline.queue = queue;
	trampoline.target = target;
	[trampoline startObservingOnObject:self options:options];
	return trampoline;
}

- (BOOL)removeObserverWithIdentifier:(id)identifier {
	return [self removeObserverTrampoline:identifier];
}

- (BOOL)removeObserverTrampoline:(GHKVOTrampoline *)trampoline {
	if(trampoline.observer != self) return NO;
	
	[trampoline stopObserving];

	return YES;
}

@end
