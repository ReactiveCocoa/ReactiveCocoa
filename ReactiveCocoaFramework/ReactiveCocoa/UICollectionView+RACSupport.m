//
//  UICollectionView+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-23.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "UICollectionView+RACSupport.h"

#import "EXTScope.h"
#import "NSIndexSet+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "RACOrderedCollectionMutation.h"
#import "RACInsertionMutation.h"
#import "RACMoveMutation.h"
#import "RACRemovalMutation.h"
#import "RACReplacementMutation.h"
#import "RACSignal+Operations.h"

@implementation UICollectionView (RACSupport)

- (RACDisposable *)rac_animateOrderedMutations:(RACSignal *)orderedMutations inSection:(NSInteger)sectionIndex {
	NSCParameterAssert(orderedMutations != nil);
	NSCParameterAssert(sectionIndex >= 0);

	NSIndexPath * (^indexPathWithIndex)(NSUInteger) = ^(NSUInteger index) {
		return [NSIndexPath indexPathForItem:(NSInteger)index inSection:sectionIndex];
	};

	NSArray * (^indexPathsWithIndexSet)(NSIndexSet *) = ^(NSIndexSet *indexSet) {
		return [[indexSet.rac_signal
			map:^(NSNumber *index) {
				return indexPathWithIndex(index.unsignedIntegerValue);
			}]
			array];
	};

	@weakify(self);
	return [[orderedMutations
		takeUntil:self.rac_willDeallocSignal]
		subscribeNext:^(id mutation) {
			@strongify(self);
			NSCAssert([mutation conformsToProtocol:@protocol(RACOrderedCollectionMutation)], @"Expected ordered collection mutation, got %@", mutation);

			if ([mutation isKindOfClass:RACInsertionMutation.class]) {
				[self insertItemsAtIndexPaths:indexPathsWithIndexSet([mutation indexes])];
			} else if ([mutation isKindOfClass:RACRemovalMutation.class]) {
				[self deleteItemsAtIndexPaths:indexPathsWithIndexSet([mutation indexes])];
			} else if ([mutation isKindOfClass:RACReplacementMutation.class]) {
				[self reloadItemsAtIndexPaths:indexPathsWithIndexSet([mutation indexes])];
			} else if ([mutation isKindOfClass:RACMoveMutation.class]) {
				[self moveItemAtIndexPath:indexPathWithIndex([mutation fromIndex]) toIndexPath:indexPathWithIndex([mutation toIndex])];
			} else {
				[self reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)sectionIndex]];
			}
		} error:^(NSError *error) {
			@strongify(self);
			NSCAssert(NO, @"Received error from ordered mutations signal %@ bound to %@: %@", orderedMutations, self, error);
		}];
}

@end
