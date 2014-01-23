//
//  UITextView+RACSupport.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RACDeprecated.h"

@class RACDelegateProxy;
@class RACSignal;

@interface UITextView (RACSupport)

/// Creates a signal for the text of the receiver.
///
/// Returns a signal which will send the current text upon subscription, then
/// again whenever the receiver's text is changed. The signal will complete when
/// the receiver is deallocated.
- (RACSignal *)rac_textSignal;

@end

@interface UITextView (RACSupportDeprecated)

@property (nonatomic, strong, readonly) RACDelegateProxy *rac_delegateProxy RACDeprecated("Use the `delegate` property of UITextView normally.");

@end

@interface UITextView (RACSupportUnavailable)

- (RACSignal *)rac_signalForDelegateMethod:(SEL)method __attribute__((unavailable("Use -rac_signalForSelector:fromProtocol: instead")));

@end
