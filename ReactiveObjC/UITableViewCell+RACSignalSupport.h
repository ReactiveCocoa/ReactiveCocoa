//
//  UITableViewCell+RACSignalSupport.h
//  ReactiveObjC
//
//  Created by Justin Spahr-Summers on 2013-07-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

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
