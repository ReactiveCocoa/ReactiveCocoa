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

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath {
	return [[[self
		rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionInitial]
		reduceEach:^(id value, NSDictionary *change) {
			return value;
		}]
		setNameWithFormat:@"RACObserve(%@, %@)", self.rac_description, keyPath];
}

- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options {
	keyPath = [keyPath copy];

	NSRecursiveLock *objectLock = [[NSRecursiveLock alloc] init];
	objectLock.name = @"com.github.ReactiveCocoa.NSObjectRACPropertySubscribing";

	__block __unsafe_unretained NSObject *unsafeSelf = self;

	RACSignal *deallocSignal = [self.rac_willDeallocSignal doCompleted:^{
		// Forces deallocation to wait if the object variable is currently
		// being read on another thread.
		[objectLock lock];
		@onExit {
			[objectLock unlock];
		};

		unsafeSelf = nil;
	}];

	return [[[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			// Hold onto the lock the whole time we're setting up the KVO
			// observation, because any resurrection that might be caused by our
			// retaining below must be balanced out by the time -dealloc returns
			// (if another thread is waiting on the lock above).
			[objectLock lock];
			@onExit {
				[objectLock unlock];
			};

			__strong NSObject *self __attribute__((objc_precise_lifetime)) = unsafeSelf;

			if (self == nil) {
				[subscriber sendCompleted];
				return;
			}

			[subscriber.disposable addDisposable:[self rac_observeKeyPath:keyPath options:options block:^(id value, NSDictionary *change) {
				[subscriber sendNext:RACTuplePack(value, change)];
			}]];
		}]
		takeUntil:deallocSignal]
		setNameWithFormat:@"%@ -rac_valueAndChangesForKeyPath: %@ options: %lu", self.rac_description, keyPath, (unsigned long)options];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

@implementation NSObject (RACDeprecatedPropertySubscribing)

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [[self
		rac_valuesForKeyPath:keyPath]
		takeUntil:observer.rac_willDeallocSignal];
}

- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer {
	return [[self
		rac_valuesAndChangesForKeyPath:keyPath options:options]
		takeUntil:observer.rac_willDeallocSignal];
}

@end

#pragma clang diagnostic pop
