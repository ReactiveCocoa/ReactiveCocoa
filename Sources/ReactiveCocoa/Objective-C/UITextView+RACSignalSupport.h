//
//  UITextView+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACDelegateProxy;
@class RACSignal;

@interface UITextView (RACSignalSupport)

/// A delegate proxy which will be set as the receiver's delegate when any of the
/// methods in this category are used.
@property (nonatomic, strong, readonly) RACDelegateProxy *rac_delegateProxy;

/// Creates a signal for the text of the receiver.
///
/// When this method is invoked, the `rac_delegateProxy` will become the
/// receiver's delegate. Any previous delegate will become the -[RACDelegateProxy
/// rac_proxiedDelegate], so that it receives any messages that the proxy doesn't
/// know how to handle. Setting the receiver's `delegate` afterward is
/// considered undefined behavior.
///
/// Returns a signal which will send the current text upon subscription, then
/// again whenever the receiver's text is changed. The signal will complete when
/// the receiver is deallocated.
- (RACSignal *)rac_textSignal;

@end

@interface UITextView (RACSignalSupportUnavailable)

- (RACSignal *)rac_signalForDelegateMethod:(SEL)method __attribute__((unavailable("Use -rac_signalForSelector:fromProtocol: instead")));

@end
