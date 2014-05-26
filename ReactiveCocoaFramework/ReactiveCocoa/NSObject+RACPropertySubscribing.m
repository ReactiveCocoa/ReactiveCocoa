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

static NSArray *RACConvertToArray(id collection) {
	if (collection == nil) return @[];
	// nil value is represented as NSNull.null in KVO change dictionary.
	// So we treat NSNull.null as same as nil.
	if (collection == NSNull.null) return @[];
	if ([collection isKindOfClass:NSArray.class]) return collection;
	if ([collection isKindOfClass:NSSet.class]) return [collection allObjects];
	if ([collection isKindOfClass:NSOrderedSet.class]) return [collection array];

	NSCParameterAssert([collection conformsToProtocol:@protocol(NSFastEnumeration)]);

	NSMutableArray *enumeratedObjects = [[NSMutableArray alloc] init];
	for (id obj in collection) {
		[enumeratedObjects addObject:obj];
	}

	return enumeratedObjects;
}

@implementation NSObject (RACPropertySubscribing)

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath {
	return [[[self
		rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionInitial]
		reduceEach:^(id value, NSDictionary *change) {
			return value;
		}]
		setNameWithFormat:@"RACObserve(%@, %@)", self.rac_description, keyPath];
}

- (RACSignal *)rac_valuesAndCollectionMutationsForKeyPath:(NSString *)keyPath {
	return [[[self
		rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial]
		reduceEach:^(id value, NSDictionary *change) {
			NSCAssert(value == nil || [value conformsToProtocol:@protocol(NSFastEnumeration)], @"Expected an enumerable collection at key path \"%@\", instead got %@", keyPath, value);

			NSKeyValueChange kind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
			NSIndexSet *indexes = change[NSKeyValueChangeIndexesKey];
			id oldObjects = change[NSKeyValueChangeOldKey];
			id newObjects = change[NSKeyValueChangeNewKey];

			NSObject<RACCollectionMutation> *mutation;

			switch (kind) {
				case NSKeyValueChangeReplacement:
					if (indexes != nil) {
						// Only use `RACReplacementMutation` for ordered
						// collections.
						oldObjects = RACConvertToArray(oldObjects);
						newObjects = RACConvertToArray(newObjects);

						mutation = [[RACReplacementMutation alloc] initWithRemovedObjects:oldObjects addedObjects:newObjects indexes:indexes];
						break;
					}

					// Otherwise, fall through and act like the entire
					// collection was replaced (see `NSKeyValueSetSetMutation`).
					newObjects = value;

				case NSKeyValueChangeSetting:
					newObjects = RACConvertToArray(newObjects);
					mutation = [[RACSettingMutation alloc] initWithObjects:newObjects];

					break;

				case NSKeyValueChangeInsertion:
					newObjects = RACConvertToArray(newObjects);

					if (indexes == nil) {
						mutation = [[RACUnionMutation alloc] initWithObjects:newObjects];
					} else {
						mutation = [[RACInsertionMutation alloc] initWithObjects:newObjects indexes:indexes];
					}

					break;

				case NSKeyValueChangeRemoval:
					oldObjects = RACConvertToArray(oldObjects);

					if (indexes == nil) {
						mutation = [[RACMinusMutation alloc] initWithObjects:oldObjects];
					} else {
						mutation = [[RACRemovalMutation alloc] initWithObjects:oldObjects indexes:indexes];
					}

					break;

				default:
					NSCAssert(NO, @"Unrecognized KVO change kind: %lu", (unsigned long)kind);
					__builtin_unreachable();
			}

			return RACTuplePack(value, mutation);
		}]
		setNameWithFormat:@"%@ -rac_valuesAndCollectionMutationsForKeyPath: %@", self.rac_description, keyPath];
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
