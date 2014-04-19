//
//  UIImagePickerController+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Timur Kuchkarov on 28.03.14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACDelegateProxy;
@class RACSignal;

@interface UIImagePickerController (RACSignalSupport)

/// A delegate proxy which will be set as the receiver's delegate when any of the
/// methods in this category are used.
@property (nonatomic, strong, readonly) RACDelegateProxy *rac_delegateProxy;

/// Creates a signal for every new selected image
///
/// When this method is invoked, the `rac_delegateProxy` will become the
/// receiver's delegate. Any previous delegate will become the -[RACDelegateProxy
/// rac_proxiedDelegate], so that it receives any messages that the proxy doesn't
/// know how to handle. Setting the receiver's `delegate` afterward is considered
/// undefined behavior.
///
/// Returns a signal which will send the dictionary with user info of selected image.
/// You are responsible for picker controller dismissal.
/// Next value will be either NSDictionary if user selected image or nil if he cancelled selection.
/// The signal will complete itself when the receiver is deallocated.
- (RACSignal *)rac_imageSelectedSignal;

@end
