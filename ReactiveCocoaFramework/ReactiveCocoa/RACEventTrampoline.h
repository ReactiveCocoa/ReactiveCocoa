//
//  RACEventTrampoline.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ReactiveCocoa/RACSubject.h>

extern const char *RACEventTrampolinesKey;

@class RACDelegateProxy;

@interface RACEventTrampoline : NSObject {
    SEL delegateMethod;
    RACDelegateProxy *proxy;
}

+ (instancetype)trampolineForControl:(UIControl *)control controlEvents:(UIControlEvents)controlEvents;
+ (instancetype)trampolineForTextView:(UITextView *)textView delegateMethod:(SEL)method;

// Returns an event trampoline for the given gesture.
+ (instancetype)trampolineForGestureRecognizer:(UIGestureRecognizer *)gesture;

- (void)didGetControlEvent:(id)sender;
- (void)didGetDelegateEvent:(SEL)delegateMethod sender:(id)sender;

@property (nonatomic, strong) RACSubject *subject;
@property (nonatomic, strong) RACDelegateProxy *proxy;
@property (nonatomic) SEL delegateMethod;

@end
