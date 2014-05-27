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

/// Sends an CADisplayLink instance whenever the screen’s contents need to be updated.
/// @Returns a signal that never completes.
+ (RACSignal *)rac_displayLinkSignalWithFrameInterval:(NSInteger)frameInterval;

@end
