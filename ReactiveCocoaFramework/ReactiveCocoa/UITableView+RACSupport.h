//
//  UITableView+RACSupport.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACDisposable;
@class RACSignal;

@interface UITableView (RACSupport)

/// Automatically inserts, removes, and reloads rows in a section of the table
/// view, based on the ordered collection mutations received from the given
/// signal.
///
/// Multiple sections can be bound within the same table view.
///
/// orderedMutations   - A signal of <RACOrderedCollectionMutation> objects
///                      describing the indexes that should be updated in the
///                      section. The actual objects being modified are
///                      ignored. This signal should never error.
/// sectionIndex       - The section that should be bound and automatically
///                      updated.
/// insertionAnimation - Specifies how inserted rows should be animated in.
/// deletionAnimation  - Specifies how deleted rows should be animated out.
/// reloadAnimation    - Specifies how reloaded rows should be animated.
///
/// Returns a disposable which can be used to cancel the binding.
- (RACDisposable *)rac_animateOrderedMutations:(RACSignal *)orderedMutations inSection:(NSInteger)sectionIndex withInsertionAnimation:(UITableViewRowAnimation)insertionAnimation deletionAnimation:(UITableViewRowAnimation)deletionAnimation reloadAnimation:(UITableViewRowAnimation)reloadAnimation;

@end
