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

static const void *RACObjectDisposables = &RACObjectDisposables;

@implementation NSObject (RACPropertySubscribing)

+ (RACSubscribable *)rac_subscribableFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject {
	RACReplaySubject *subject = [RACReplaySubject replaySubjectWithCapacity:1];
	[onObject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		[subject sendCompleted];
	}]];
	
	__unsafe_unretained NSObject *weakObject = object;
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

- (void)rac_addDeallocDisposable:(RACDisposable *)disposable {
	@synchronized(self) {
		NSSet *disposables = objc_getAssociatedObject(self, RACObjectDisposables) ?: [NSSet set];
		disposables = [disposables setByAddingObject:[disposable asScopedDisposable]];
		objc_setAssociatedObject(self, RACObjectDisposables, disposables, OBJC_ASSOCIATION_RETAIN);
	}
}

@end
