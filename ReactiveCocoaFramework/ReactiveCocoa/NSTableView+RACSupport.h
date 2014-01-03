//
//  NSTableView+RACSupport.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-01.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class RACDisposable;
@class RACSignal;

@interface NSTableView (RACSupport)

/// Automatically inserts, removes, and reloads rows in the table view, based on
/// the ordered collection mutations received from the given signal.
///
/// This method only supports view-based table views.
///
/// orderedMutations - A signal of <RACOrderedCollectionMutation> objects
///                    describing the indexes that should be updated in the
///                    table view. The actual objects being modified are
///                    ignored. This signal should never error.
/// insertionOptions - Options describing how insertions into the table view
///                    should be animated.
/// removalOptions   - Options describing how removals from the table view
///                    should be animated.
///
/// Returns a disposable which can be used to cancel the binding.
- (RACDisposable *)rac_animateOrderedMutations:(RACSignal *)orderedMutations withInsertionAnimation:(NSTableViewAnimationOptions)insertionOptions removalAnimation:(NSTableViewAnimationOptions)removalOptions;

@end
