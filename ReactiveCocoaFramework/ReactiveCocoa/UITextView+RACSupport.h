//
//  UITextView+RACSupport.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <UIKit/UIKit.h>


@class RACSignal;

@interface UITextView (RACSupport)

/// Creates a signal for the text of the receiver.
///
/// Returns a signal which will send the current text upon subscription, then
/// again whenever the receiver's text is changed. The signal will complete when
/// the receiver is deallocated.
- (RACSignal *)rac_textSignal;

@end

@class RACDelegateProxy;
@interface UITextView (RACSignalSupportUnavailable)


@property (nonatomic, strong, readonly) RACDelegateProxy *rac_delegateProxy __attribute__((unavailable("Use the `delegate` property of UITextView normally.")));
- (RACSignal *)rac_signalForDelegateMethod:(SEL)method __attribute__((unavailable("Use -rac_signalForSelector:fromProtocol: instead")));

@end
