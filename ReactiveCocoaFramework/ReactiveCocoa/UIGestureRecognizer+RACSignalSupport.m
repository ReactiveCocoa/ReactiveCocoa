//
//  UIGestureRecognizer+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Travis Jeffery on 5/15/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIGestureRecognizer+RACSignalSupport.h"
#import "RACEventTrampoline.h"

@implementation UIGestureRecognizer (RACSignalSupport)

- (RACSignal *)rac_signalForGesture {
    RACEventTrampoline *trampoline = [RACEventTrampoline trampolineForGestureRecognizer:self];
    [trampoline.subject setNameWithFormat:@"%@ -rac_signalForGesture", self];

    NSMutableSet *gestureRecognizerEventTrampolines = objc_getAssociatedObject(self, RACEventTrampolinesKey);
    if (gestureRecognizerEventTrampolines == nil) {
        gestureRecognizerEventTrampolines = [NSMutableSet set];
        objc_setAssociatedObject(self, RACEventTrampolinesKey, gestureRecognizerEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [gestureRecognizerEventTrampolines addObject:trampoline];

    return trampoline.subject;
}

@end
