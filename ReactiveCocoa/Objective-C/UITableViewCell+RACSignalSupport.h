//
//  UITableViewCell+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RACSubscriptingAssignmentTrampoline.h"

@class RACSignal;

@interface UITableViewCell (RACSignalSupport)

/// A signal which will send a RACUnit whenever -prepareForReuse is invoked upon
/// the receiver.
///
/// Examples
///
///  [[[self.cancelButton
///     rac_signalForControlEvents:UIControlEventTouchUpInside]
///     takeUntil:self.rac_prepareForReuseSignal]
///     subscribeNext:^(UIButton *x) {
///         // do other things
///     }];
@property (nonatomic, strong, readonly) RACSignal *rac_prepareForReuseSignal;

@end

/// Same as RACOnMainThread but it's used for cells.
/// Please make sure the TARGET is kind of UITableViewCell.
#define RACCell(TARGET, ...) \
	metamacro_if_eq(1, metamacro_argcount(__VA_ARGS__)) \
		(RACCell_(TARGET, __VA_ARGS__, nil)) \
		(RACCell_(TARGET, __VA_ARGS__))

/// Do not use this directly. Use the RACCell macro above.
#define RACCell_(TARGET, KEYPATH, NILVALUE) \
	[[SAKSubscriptingAssignmentTrampolineForCell alloc] initWithTarget:(TARGET) nilValue:(NILVALUE)][@keypath(TARGET, KEYPATH)]

@interface SAKSubscriptingAssignmentTrampolineForCell : SAKSubscriptingAssignmentTrampolineOnMainThread

@end
