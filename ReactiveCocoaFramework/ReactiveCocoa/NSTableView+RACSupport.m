//
//  NSTableView+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-01.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "NSTableView+RACSupport.h"

#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "RACOrderedCollectionMutation.h"
#import "RACInsertionMutation.h"
#import "RACMoveMutation.h"
#import "RACRemovalMutation.h"
#import "RACReplacementMutation.h"
#import "RACSignal+Operations.h"

@implementation NSTableView (RACSupport)

- (RACDisposable *)rac_animateOrderedMutations:(RACSignal *)orderedMutations withInsertionAnimation:(NSTableViewAnimationOptions)insertionOptions removalAnimation:(NSTableViewAnimationOptions)removalOptions {
	NSCParameterAssert(orderedMutations != nil);

	@weakify(self);
	return [[orderedMutations
		takeUntil:self.rac_willDeallocSignal]
		subscribeNext:^(id mutation) {
			@strongify(self);
			NSCAssert([mutation conformsToProtocol:@protocol(RACOrderedCollectionMutation)], @"Expected ordered collection mutation, got %@", mutation);

			if ([mutation isKindOfClass:RACInsertionMutation.class]) {
				[self beginUpdates];
				[self insertRowsAtIndexes:[mutation indexes] withAnimation:insertionOptions];
				[self endUpdates];
			} else if ([mutation isKindOfClass:RACRemovalMutation.class]) {
				[self beginUpdates];
				[self removeRowsAtIndexes:[mutation indexes] withAnimation:removalOptions];
				[self endUpdates];
			} else if ([mutation isKindOfClass:RACReplacementMutation.class]) {
				NSIndexSet *columnIndexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, (NSUInteger)self.numberOfColumns)];

				[self beginUpdates];
				[self reloadDataForRowIndexes:[mutation indexes] columnIndexes:columnIndexes];
				[self noteHeightOfRowsWithIndexesChanged:[mutation indexes]];
				[self endUpdates];
			} else if ([mutation isKindOfClass:RACMoveMutation.class]) {
				[self beginUpdates];
				[self moveRowAtIndex:(NSInteger)[mutation fromIndex] toIndex:(NSInteger)[mutation toIndex]];
				[self endUpdates];
			} else {
				[self reloadData];
			}
		} error:^(NSError *error) {
			@strongify(self);
			NSCAssert(NO, @"Received error from ordered mutations signal %@ bound to %@: %@", orderedMutations, self, error);
		}];
}

@end
