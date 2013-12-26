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
	return [[[self rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionInitial observer:observer] reduceEach:^(id value, NSDictionary *change) {
		return value;
	}] setNameWithFormat:@"RACObserve(%@, %@)", self.rac_description, keyPath];
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

	RACDisposable *deallocFlagDisposable = [[RACDisposable alloc] init];
	RACCompoundDisposable *observerDisposable = observer.rac_deallocDisposable;
	RACCompoundDisposable *objectDisposable = self.rac_deallocDisposable;
	[observerDisposable addDisposable:deallocFlagDisposable];
	[objectDisposable addDisposable:deallocFlagDisposable];

	@unsafeify(self, observer);
	return [RACSignal create:^(id<RACSubscriber> subscriber) {
		if (deallocFlagDisposable.disposed) {
			[subscriber sendCompleted];
			return;
		}

		@strongify(self, observer);

		RACDisposable *observationDisposable = [self rac_observeKeyPath:keyPath options:options observer:observer block:^(id value, NSDictionary *change) {
			[subscriber sendNext:RACTuplePack(value, change)];
		}];

		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			[observationDisposable dispose];
			[subscriber sendCompleted];
		}];

		[observer.rac_deallocDisposable addDisposable:deallocDisposable];
		[self.rac_deallocDisposable addDisposable:deallocDisposable];

		[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
			[observerDisposable removeDisposable:deallocFlagDisposable];
			[objectDisposable removeDisposable:deallocFlagDisposable];
			[observerDisposable removeDisposable:deallocDisposable];
			[objectDisposable removeDisposable:deallocDisposable];
			[observationDisposable dispose];
		}]];
	}];
}

@end
