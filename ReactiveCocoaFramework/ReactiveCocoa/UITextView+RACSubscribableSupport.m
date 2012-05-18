//
//  UITextView+RACSubscribableSupport.m
//  Heading
//
//  Created by Cody Krieger on 5/18/12.
//  Copyright (c) 2012 Cody Krieger. All rights reserved.
//

#import "UITextView+RACSubscribableSupport.h"
#import "RACSubject.h"
#import "RACSubscribable+Operations.h"
#import <objc/runtime.h>

@interface RACTextViewEventTrampoline : NSObject <UITextViewDelegate>
@property (nonatomic, strong) RACSubject *subject;
@end

@implementation RACTextViewEventTrampoline

@synthesize subject;

+ (RACTextViewEventTrampoline *)trampolineForControl:(UITextView *)control ControlEvents:(UIControlEvents)controlEvents {
	RACTextViewEventTrampoline *trampoline = [[self alloc] init];
    
    if (controlEvents & UIControlEventEditingChanged) {
        [control setDelegate:trampoline];
    }
    
	return trampoline;
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

- (void)textViewDidChange:(UITextView *)textView {
    [self didGetControlEvent:textView];
}

@end


const void *RACUITextViewEventTrampolinesKey = "RACUITextViewEventTrampolinesKey";

@implementation UITextView (RACSubscribableSupport)

- (RACSubscribable *)rac_subscribableForControlEvents:(UIControlEvents)controlEvents {
	RACTextViewEventTrampoline *trampoline = [RACTextViewEventTrampoline trampolineForControl:self ControlEvents:controlEvents];
    
	NSMutableSet *controlEventTrampolines = objc_getAssociatedObject(self, RACUITextViewEventTrampolinesKey);
	if(controlEventTrampolines == nil) {
		controlEventTrampolines = [NSMutableSet set];
		objc_setAssociatedObject(self, RACUITextViewEventTrampolinesKey, controlEventTrampolines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	[controlEventTrampolines addObject:trampoline];
	
	return trampoline.subject;
}

- (RACSubscribable *)rac_textSubscribable {
	return [[self rac_subscribableForControlEvents:UIControlEventEditingChanged] select:^(id x) {
		return [x text];
	}];
}

@end
