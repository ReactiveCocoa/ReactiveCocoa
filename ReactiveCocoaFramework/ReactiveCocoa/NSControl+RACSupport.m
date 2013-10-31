//
//  NSControl+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/3/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCommand.h"
#import "RACScopedDisposable.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import <objc/runtime.h>

static void *NSControlRACCommandKey = &NSControlRACCommandKey;
static void *NSControlEnabledDisposableKey = &NSControlEnabledDisposableKey;

@implementation NSControl (RACSupport)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, NSControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, NSControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	// Tear down any previous binding before setting up our new one, or else we
	// might get assertion failures.
	[objc_getAssociatedObject(self, NSControlEnabledDisposableKey) dispose];
	objc_setAssociatedObject(self, NSControlEnabledDisposableKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	if (command == nil) {
		self.enabled = YES;
		return;
	}
	
	[self rac_hijackActionAndTargetIfNeeded];

	RACScopedDisposable *disposable = [[command.enabled setKeyPath:@"enabled" onObject:self] asScopedDisposable];
	objc_setAssociatedObject(self, NSControlEnabledDisposableKey, disposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)rac_hijackActionAndTargetIfNeeded {
	SEL hijackSelector = @selector(rac_commandPerformAction:);
	if (self.target == self && self.action == hijackSelector) return;
	
	if (self.target != nil) NSLog(@"WARNING: NSControl.rac_command hijacks the control's existing target and action.");
	
	self.target = self;
	self.action = hijackSelector;
}

- (void)rac_commandPerformAction:(id)sender {
	[self.rac_command execute:sender];
}

- (RACSignal *)rac_textSignal {
	@weakify(self);
	return [[[[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);
			id observer = [NSNotificationCenter.defaultCenter addObserverForName:NSControlTextDidChangeNotification object:self queue:nil usingBlock:^(NSNotification *note) {
				[subscriber sendNext:note.object];
			}];

			return [RACDisposable disposableWithBlock:^{
				[NSNotificationCenter.defaultCenter removeObserver:observer];
			}];
		}]
		map:^(NSControl *control) {
			return [control.stringValue copy];
		}]
		startWith:[self.stringValue copy]]
		setNameWithFormat:@"%@ -rac_textSignal", [self rac_description]];
}

@end
