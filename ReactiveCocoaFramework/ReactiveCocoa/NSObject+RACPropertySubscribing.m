//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import <objc/runtime.h>
#import "NSObject+RACKVOWrapper.h"
#import "RACReplaySubject.h"
#import "RACDisposable.h"
#import "RACSwizzling.h"
#import "RACSubscribable+Private.h"
#import "RACSubscribable+Operations.h"

static const void *RACPropertySubscribingDisposables = &RACPropertySubscribingDisposables;


@implementation NSObject (RACPropertySubscribing)

#pragma mark Lazy

+ (NSMutableDictionary *)swizzledClasses {
	static dispatch_once_t onceToken;
	static NSMutableDictionary *swizzledClasses = nil;
	dispatch_once(&onceToken, ^{
		swizzledClasses = [[NSMutableDictionary alloc] init];
	});

	return swizzledClasses;
}

#pragma mark API

- (void)rac_propertySubscribingDealloc {
	NSMutableSet *disposables = objc_getAssociatedObject(self, RACPropertySubscribingDisposables);
	for(RACDisposable *disposable in [disposables copy]) {
		[disposable dispose];
	}
	
	objc_setAssociatedObject(self, RACPropertySubscribingDisposables, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	[self rac_propertySubscribingDealloc];
}

+ (RACSubscribable *)rac_subscribableFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject {
	RACReplaySubject *subject = [RACReplaySubject replaySubjectWithCapacity:1];
	
	@synchronized([self swizzledClasses]) {
		Class class = [onObject class];
		NSString *keyName = NSStringFromClass(class);
		if([[self swizzledClasses] objectForKey:keyName] == nil) {
			RACSwizzle(class, NSSelectorFromString(@"dealloc"), @selector(rac_propertySubscribingDealloc));
			[[self swizzledClasses] setObject:[NSNull null] forKey:keyName];
		}
	}
	
	@synchronized(self) {
		NSMutableSet *disposables = objc_getAssociatedObject(onObject, RACPropertySubscribingDisposables);
		if(disposables == nil) {
			disposables = [NSMutableSet set];
			objc_setAssociatedObject(onObject, RACPropertySubscribingDisposables, disposables, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		
		[disposables addObject:[RACDisposable disposableWithBlock:^{
			// tear down the subscribable without sending notifications to the subscribers, since they could have already been dealloc'd by this point
			[subject tearDown];
		}]];
	}
	
	__block __unsafe_unretained NSObject *weakObject = object;
	[object rac_addObserver:onObject forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongObject = weakObject;
		[subject sendNext:[strongObject valueForKeyPath:keyPath]];
	}];
	
	return subject;
}

- (RACSubscribable *)rac_subscribableForKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
	return [[self class] rac_subscribableFor:self keyPath:keyPath onObject:object];
}

- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSubscribable *)subscribable {
	return [subscribable toProperty:keyPath onObject:self];
}

@end
