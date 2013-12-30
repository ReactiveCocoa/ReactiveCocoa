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
#import "RACInsertionMutation.h"
#import "RACKVOTrampoline.h"
#import "RACMinusMutation.h"
#import "RACRemovalMutation.h"
#import "RACReplacementMutation.h"
#import "RACSettingMutation.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import "RACTuple.h"
#import "RACUnionMutation.h"

#import <libkern/OSAtomic.h>

@implementation NSObject (RACPropertySubscribing)

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [[[self
		rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionInitial observer:observer]
		reduceEach:^(id value, NSDictionary *change) {
			return value;
		}]
		setNameWithFormat:@"RACObserve(%@, %@)", self.rac_description, keyPath];
}

- (RACSignal *)rac_valuesAndCollectionMutationsForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [[[self
		rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial observer:observer]
		reduceEach:^(id value, NSDictionary *change) {
			NSKeyValueChange kind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
			NSArray *oldObjects = change[NSKeyValueChangeOldKey];
			NSArray *newObjects = change[NSKeyValueChangeNewKey];
			NSIndexSet *indexes = change[NSKeyValueChangeIndexesKey];

			if (value != nil) {
				NSCAssert([value conformsToProtocol:@protocol(RACCollection)], @"Value is not a collection: %@", value);
				NSCAssert(indexes == nil || [value conformsToProtocol:@protocol(RACOrderedCollection)], @"Indexes given, but value is not an ordered collection: %@", value);
			}

			NSObject<RACCollectionMutation> *mutation;

			switch (kind) {
				case NSKeyValueChangeSetting:
					mutation = [[RACSettingMutation alloc] initWithObjects:newObjects ?: @[]];
					break;

				case NSKeyValueChangeInsertion:
					if (indexes == nil) {
						mutation = [[RACUnionMutation alloc] initWithObjects:newObjects];
					} else {
						mutation = [[RACInsertionMutation alloc] initWithObjects:newObjects indexes:indexes];
					}

					break;

				case NSKeyValueChangeRemoval:
					if (indexes == nil) {
						mutation = [[RACMinusMutation alloc] initWithObjects:oldObjects];
					} else {
						mutation = [[RACRemovalMutation alloc] initWithObjects:oldObjects indexes:indexes];
					}

					break;

				case NSKeyValueChangeReplacement:
					// Only ordered collections generate replacements.
					NSCAssert(indexes != nil, @"Replacement change %@ received for unordered collection: %@", change, value);

					mutation = [[RACReplacementMutation alloc] initWithRemovedObjects:oldObjects addedObjects:newObjects indexes:indexes];
					break;

				default:
					NSCAssert(NO, @"Unrecognized KVO change kind: %lu", (unsigned long)kind);
					__builtin_unreachable();
			}

			if ([value conformsToProtocol:@protocol(RACOrderedCollection)]) {
				NSCAssert([mutation conformsToProtocol:@protocol(RACOrderedCollectionMutation)], @"Mutation %@ is not ordered, but the affected collection is: %@", mutation, value);
			}

			return RACTuplePack(value, mutation);
		}]
		setNameWithFormat:@"%@ -rac_valuesAndCollectionMutationsForKeyPath: %@ observer: %@", self.rac_description, keyPath, observer.rac_description];
}

- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer {
	keyPath = [keyPath copy];

	NSRecursiveLock *objectLock = [[NSRecursiveLock alloc] init];
	objectLock.name = @"com.github.ReactiveCocoa.NSObjectRACPropertySubscribing";

	__block __unsafe_unretained NSObject *unsafeSelf = self;
	__block __unsafe_unretained NSObject *unsafeObserver = observer;

	RACSignal *deallocSignal = [[RACSignal
		zip:@[
			self.rac_willDeallocSignal,
			observer.rac_willDeallocSignal ?: [RACSignal never]
		]]
		doCompleted:^{
			// Forces deallocation to wait if the object variables are currently
			// being read on another thread.
			[objectLock lock];
			@onExit {
				[objectLock unlock];
			};

			unsafeSelf = nil;
			unsafeObserver = nil;
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

			__strong NSObject *observer __attribute__((objc_precise_lifetime)) = unsafeObserver;
			__strong NSObject *self __attribute__((objc_precise_lifetime)) = unsafeSelf;

			if (self == nil) {
				[subscriber sendCompleted];
				return;
			}

			[subscriber.disposable addDisposable:[self rac_observeKeyPath:keyPath options:options observer:observer block:^(id value, NSDictionary *change) {
				[subscriber sendNext:RACTuplePack(value, change)];
			}]];
		}]
		takeUntil:deallocSignal]
		setNameWithFormat:@"%@ -rac_valueAndChangesForKeyPath: %@ options: %lu observer: %@", self.rac_description, keyPath, (unsigned long)options, observer.rac_description];
}

@end
