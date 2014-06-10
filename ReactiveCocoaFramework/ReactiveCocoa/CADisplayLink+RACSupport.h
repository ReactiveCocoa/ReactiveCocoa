//
//  CADisplayLink+RACSupport.h
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2014/05/12.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@class RACSignal;

@interface CADisplayLink (RACSupport)

/// A signal that fires whenever the screen’s contents need to be updated.
///
/// Returns a signal that sends the receiver whenever an update should occur.
/// The returned signal will never complete naturally, and must therefore be
/// disposed manually or with an operator like -takeUntil:.
+ (RACSignal *)rac_displayLinkSignalWithFrameInterval:(NSInteger)frameInterval;

@end
