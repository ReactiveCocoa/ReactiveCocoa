//
//  UITableViewHeaderFooterView+RACSignalSupport.h
//  ReactiveObjC
//
//  Created by Syo Ikeda on 12/30/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACSignal;

// This category is only applicable to iOS >= 6.0.
@interface UITableViewHeaderFooterView (RACSignalSupport)

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
