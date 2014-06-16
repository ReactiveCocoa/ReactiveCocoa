//
//  CADisplayLink+RACSupport.m
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2014/05/12.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "CADisplayLink+RACSupport.h"

#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"

@implementation CADisplayLink (RACSupport)

+ (RACSignal *)rac_displayLinkSignalWithFrameInterval:(NSInteger)frameInterval {
	return [[RACSignal
		create:^(id<RACSubscriber> subscriber) {
			CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:subscriber selector:@selector(sendNext:)];
			displayLink.frameInterval = frameInterval;
			
			if (subscriber.disposable.disposed) return;
			[displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSDefaultRunLoopMode];

			[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
				[displayLink invalidate];
			}]];
		}]
		setNameWithFormat:@"%@ -rac_displayLinkSignalWithFrameInterval:%td", self.rac_description, frameInterval];
}

@end
