//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import <objc/runtime.h>

static const void *RACObjectDisposables = &RACObjectDisposables;

@implementation NSObject (RACPropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath onObject:(NSObject *)onObject withChangeOptions:(NSKeyValueObservingOptions)options {
	RACReplaySubject *subject = [RACReplaySubject replaySubjectWithCapacity:1];
	[subject setNameWithFormat:@"RACAble(%@, %@)", object, keyPath];

	[onObject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		[subject sendCompleted];
	}]];
	
	__unsafe_unretained NSObject *weakObject = object;
	[object rac_addObserver:onObject forKeyPath:keyPath options:options queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongObject = weakObject;
		[subject sendNext:options ? [RACPropertyChangeBase propertyChangeForDictionary:change] : [strongObject valueForKeyPath:keyPath]];
	}];
	
	return subject;
}

- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath onObject:(NSObject *)object {
	return [self.class rac_signalFor:self keyPath:keyPath onObject:object withChangeOptions:0];
}

- (RACSignal *)rac_signalWithChangesForKeyPath:(NSString *)keyPath onObject:(NSObject *)object{
	return [self.class rac_signalFor:self keyPath:keyPath onObject:object withChangeOptions:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld | NSKeyValueObservingOptionInitial];
}

- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal {
	return [signal toProperty:keyPath onObject:self];
}

- (void)rac_addDeallocDisposable:(RACDisposable *)disposable {
	@synchronized(self) {
		NSMutableArray *disposables = objc_getAssociatedObject(self, RACObjectDisposables);
		if (disposables == nil) {
			disposables = [[NSMutableArray alloc] init];
			objc_setAssociatedObject(self, RACObjectDisposables, disposables, OBJC_ASSOCIATION_RETAIN);
		}

		[disposables addObject:disposable.asScopedDisposable];
	}
}

@end
