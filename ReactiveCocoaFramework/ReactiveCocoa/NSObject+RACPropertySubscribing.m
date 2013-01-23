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
#import "EXTScope.h"
#import "RACKVOTrampoline.h"
#import <objc/runtime.h>

static const void *RACObjectDisposables = &RACObjectDisposables;

@implementation NSObject (RACPropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer {
	@unsafeify(observer, object);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		@strongify(observer, object);
		RACKVOTrampoline *KVOTrampoline = [object rac_addObserver:observer forKeyPath:keyPath options:0 block:^(id target, id observer, NSDictionary *change) {
			[subscriber sendNext:[target valueForKeyPath:keyPath]];
		}];

		RACDisposable *KVODisposable = [RACDisposable disposableWithBlock:^{
			[KVOTrampoline stopObserving];
		}];
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			[KVODisposable dispose];
			[subscriber sendCompleted];
		}];
		[observer rac_addDeallocDisposable:deallocDisposable];
		[object rac_addDeallocDisposable:deallocDisposable];
		
		return KVODisposable;
	}] setNameWithFormat:@"RACAble(%@, %@)", object, keyPath];
}

- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [self.class rac_signalFor:self keyPath:keyPath observer:observer];
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
