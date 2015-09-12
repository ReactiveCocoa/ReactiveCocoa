//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"
#import "RACSubscriber.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import <libkern/OSAtomic.h>

@implementation NSObject (RACPropertySubscribing)

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath observer:(__weak NSObject *)observer {
	return [[[self
		rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionInitial observer:observer]
		map:^(RACTuple *value) {
			// -map: because it doesn't require the block trampoline that -reduceEach: uses
			return value[0];
		}]
		setNameWithFormat:@"RACObserve(%@, %@)", RACDescription(self), keyPath];
}

- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(__weak NSObject *)weakObserver {
	NSObject *strongObserver = weakObserver;
	keyPath = [keyPath copy];

	NSRecursiveLock *objectLock = [[NSRecursiveLock alloc] init];
	objectLock.name = @"org.reactivecocoa.ReactiveCocoa.NSObjectRACPropertySubscribing";

	__weak NSObject *weakSelf = self;

	RACSignal *deallocSignal = [[RACSignal
		zip:@[
			self.rac_willDeallocSignal,
			strongObserver.rac_willDeallocSignal ?: [RACSignal never]
		]]
		doCompleted:^{
			// Forces deallocation to wait if the object variables are currently
			// being read on another thread.
			[objectLock lock];
			@onExit {
				[objectLock unlock];
			};
		}];

	return [[[RACSignal
		createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			// Hold onto the lock the whole time we're setting up the KVO
			// observation, because any resurrection that might be caused by our
			// retaining below must be balanced out by the time -dealloc returns
			// (if another thread is waiting on the lock above).
			[objectLock lock];
			@onExit {
				[objectLock unlock];
			};

			__strong NSObject *observer __attribute__((objc_precise_lifetime)) = weakObserver;
			__strong NSObject *self __attribute__((objc_precise_lifetime)) = weakSelf;

			if (self == nil) {
				[subscriber sendCompleted];
				return nil;
			}

			return [self rac_observeKeyPath:keyPath options:options observer:observer block:^(id value, NSDictionary *change, BOOL causedByDealloc, BOOL affectedOnlyLastComponent) {
				[subscriber sendNext:RACTuplePack(value, change)];
			}];
		}]
		takeUntil:deallocSignal]
		setNameWithFormat:@"%@ -rac_valueAndChangesForKeyPath: %@ options: %lu observer: %@", RACDescription(self), keyPath, (unsigned long)options, RACDescription(strongObserver)];
}

@end

static RACSignal *signalWithoutChangesFor(Class class, NSObject *object, NSString *keyPath, NSKeyValueObservingOptions options, NSObject *observer) {
	NSCParameterAssert(object != nil);
	NSCParameterAssert(keyPath != nil);
	NSCParameterAssert(observer != nil);

	keyPath = [keyPath copy];

	@unsafeify(object);

	return [[class
		rac_signalWithChangesFor:object keyPath:keyPath options:options observer:observer]
		map:^(NSDictionary *change) {
			@strongify(object);
			return [object valueForKeyPath:keyPath];
		}];
}

@implementation NSObject (RACPropertySubscribingDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return signalWithoutChangesFor(self, object, keyPath, 0, observer);
}

+ (RACSignal *)rac_signalWithStartingValueFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return signalWithoutChangesFor(self, object, keyPath, NSKeyValueObservingOptionInitial, observer);
}

+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer {
	@unsafeify(observer, object);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {

		@strongify(observer, object);
		RACKVOTrampoline *KVOTrampoline = [object rac_addObserver:observer forKeyPath:keyPath options:options block:^(id target, id observer, NSDictionary *change) {
			[subscriber sendNext:change];
		}];

		@weakify(subscriber);
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			@strongify(subscriber);
			[KVOTrampoline dispose];
			[subscriber sendCompleted];
		}];

		[observer.rac_deallocDisposable addDisposable:deallocDisposable];
		[object.rac_deallocDisposable addDisposable:deallocDisposable];

		RACCompoundDisposable *observerDisposable = observer.rac_deallocDisposable;
		RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
		return [RACDisposable disposableWithBlock:^{
			[observerDisposable removeDisposable:deallocDisposable];
			[objectDisposable removeDisposable:deallocDisposable];
			[KVOTrampoline dispose];
		}];
	}] setNameWithFormat:@"RACAble(%@, %@)", RACDescription(object), keyPath];
}

- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [self.class rac_signalFor:self keyPath:keyPath observer:observer];
}

- (RACSignal *)rac_signalWithStartingValueForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [self.class rac_signalWithStartingValueFor:self keyPath:keyPath observer:observer];
}

- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal {
	return [signal setKeyPath:keyPath onObject:self];
}

#pragma clang diagnostic pop

@end
