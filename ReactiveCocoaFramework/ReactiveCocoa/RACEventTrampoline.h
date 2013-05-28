//
//  RACEventTrampoline.h
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ReactiveCocoa/RACSubject.h>

@class RACEventTrampoline;
@class RACDelegateProxy;

// Associates a RACEventTrampoline with the given object in order to retain the
// trampoline for the lifetime of the object.
void RACAddEventTrampoline(id object, RACEventTrampoline *trampoline);

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
