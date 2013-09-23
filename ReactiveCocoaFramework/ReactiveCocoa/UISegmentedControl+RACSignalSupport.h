//
//  UISegmentedControl+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 20/07/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RACChannelTerminal;

@interface UISegmentedControl (RACSignalSupport)

/// Creates a new RACChannel-based binding to the receiver.
///
/// nilValue - The segment to select when the terminal receives `nil`.
///
/// Returns a RACChannelTerminal that sends the receiver's currently selected
/// segment's index whenever the UIControlEventValueChanged control event is
/// fired, and sets the selected segment index to the values it receives.
- (RACChannelTerminal *)rac_newSelectedSegmentIndexChannelWithNilValue:(NSNumber *)nilValue;

@end
