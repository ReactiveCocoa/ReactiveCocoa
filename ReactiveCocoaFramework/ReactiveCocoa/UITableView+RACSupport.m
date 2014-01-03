//
//  UITableView+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "UITableView+RACSupport.h"

#import "EXTScope.h"
#import "NSIndexSet+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "RACOrderedCollectionMutation.h"
#import "RACInsertionMutation.h"
#import "RACMoveMutation.h"
#import "RACRemovalMutation.h"
#import "RACReplacementMutation.h"
#import "RACSignal+Operations.h"

@implementation UITableView (RACSupport)

- (RACDisposable *)rac_animateOrderedMutations:(RACSignal *)orderedMutations inSection:(NSInteger)sectionIndex withInsertionAnimation:(UITableViewRowAnimation)insertionAnimation deletionAnimation:(UITableViewRowAnimation)deletionAnimation reloadAnimation:(UITableViewRowAnimation)reloadAnimation {
	NSCParameterAssert(orderedMutations != nil);
	NSCParameterAssert(sectionIndex >= 0);

	NSIndexPath * (^indexPathWithIndex)(NSUInteger) = ^(NSUInteger index) {
		return [NSIndexPath indexPathForRow:(NSInteger)index inSection:sectionIndex];
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
				[self insertRowsAtIndexPaths:indexPathsWithIndexSet([mutation indexes]) withRowAnimation:insertionAnimation];
			} else if ([mutation isKindOfClass:RACRemovalMutation.class]) {
				[self deleteRowsAtIndexPaths:indexPathsWithIndexSet([mutation indexes]) withRowAnimation:deletionAnimation];
			} else if ([mutation isKindOfClass:RACReplacementMutation.class]) {
				[self reloadRowsAtIndexPaths:indexPathsWithIndexSet([mutation indexes]) withRowAnimation:reloadAnimation];
			} else if ([mutation isKindOfClass:RACMoveMutation.class]) {
				[self moveRowAtIndexPath:indexPathWithIndex([mutation fromIndex]) toIndexPath:indexPathWithIndex([mutation toIndex])];
			} else {
				[self reloadSections:[NSIndexSet indexSetWithIndex:(NSUInteger)sectionIndex] withRowAnimation:reloadAnimation];
			}
		} error:^(NSError *error) {
			@strongify(self);
			NSCAssert(NO, @"Received error from ordered mutations signal %@ bound to %@: %@", orderedMutations, self, error);
		}];
}

@end
