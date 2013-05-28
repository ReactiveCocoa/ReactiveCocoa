//
//  RACEventTrampoline.m
//  ReactiveCocoa
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACEventTrampoline.h"
#import "RACSwizzling.h"
#import "RACObjCRuntime.h"
#import "RACDelegateProxy.h"
#import <objc/runtime.h>

static void *RACEventTrampolinesKey = &RACEventTrampolinesKey;

void RACAddEventTrampoline(id object, RACEventTrampoline *trampoline) {
	NSMutableSet *eventTrampolines = objc_getAssociatedObject(object, RACEventTrampolinesKey);
	if (eventTrampolines == nil) {
		eventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(object, RACEventTrampolinesKey, eventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}

	[eventTrampolines addObject:trampoline];
}

static NSMutableDictionary *swizzledClasses() {
	static dispatch_once_t onceToken;
	static NSMutableDictionary *swizzledClasses = nil;
	dispatch_once(&onceToken, ^{
		swizzledClasses = [[NSMutableDictionary alloc] init];
	});
	
	return swizzledClasses;
}

@implementation UITextView (RACSignalSupport)

- (void)rac_setDelegate:(id<UITextViewDelegate>)delegate {
    Class proxyClass = [RACDelegateProxy class];
    
    if ([delegate isKindOfClass:proxyClass]) {
        id<UITextViewDelegate> oldDelegate = [self delegate];
        [(RACDelegateProxy *)delegate setActualDelegate:oldDelegate];
        
        [self rac_setDelegate:delegate];
    } else if ([self.delegate isKindOfClass:proxyClass]) {
        [(RACDelegateProxy *)self.delegate setActualDelegate:delegate];
    } else {
        [self rac_setDelegate:delegate];
    }
}

@end


@implementation RACEventTrampoline

@synthesize proxy;
@synthesize delegateMethod;

+ (instancetype)trampolineForControl:(UIControl *)control controlEvents:(UIControlEvents)controlEvents {
	RACEventTrampoline *trampoline = [[self alloc] init];
	[control addTarget:trampoline action:@selector(didGetControlEvent:) forControlEvents:controlEvents];
	return trampoline;
}

+ (instancetype)trampolineForGestureRecognizer:(UIGestureRecognizer *)gesture {
	RACEventTrampoline *trampoline = [[self alloc] init];
	[gesture addTarget:trampoline action:@selector(didGetControlEvent:)];

	return trampoline;
}

+ (instancetype)trampolineForTextView:(UITextView *)textView delegateMethod:(SEL)method {
    RACEventTrampoline *trampoline = [[self alloc] init];
    [trampoline setDelegateMethod:method];
    
    @synchronized(swizzledClasses()) {
        Class class = [textView class];
		NSString *keyName = NSStringFromClass(class);
		if ([swizzledClasses() objectForKey:keyName] == nil) {
			RACSwizzle(class, @selector(setDelegate:), @selector(rac_setDelegate:));
			[swizzledClasses() setObject:[NSNull null] forKey:keyName];
		}
    }
    
    if ([[textView delegate] isKindOfClass:[RACDelegateProxy class]]) {
        [(RACDelegateProxy *)textView.delegate addTrampoline:trampoline];
    } else {
        Protocol *protocol = @protocol(UITextViewDelegate);
        
        RACDelegateProxy *proxy = [RACDelegateProxy proxyWithProtocol:protocol andDelegator:textView];
        [proxy addTrampoline:trampoline];
        
        [textView setDelegate:(id<UITextViewDelegate>)proxy];
    }
    
    return trampoline;
}

- (void)dealloc {
	[_subject sendCompleted];
}

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.subject = [RACSubject subject];
	
	return self;
}

- (void)didGetControlEvent:(id)sender {
	[self.subject sendNext:sender];
}

- (void)didGetDelegateEvent:(SEL)receivedEvent sender:(id)sender {
    if (receivedEvent == delegateMethod) {
        [self didGetControlEvent:sender];
    }
}

@end
