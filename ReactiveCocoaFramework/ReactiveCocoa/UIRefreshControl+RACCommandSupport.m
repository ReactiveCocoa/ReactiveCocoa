//
//  UIRefreshControl+RACCommandSupport.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIRefreshControl+RACCommandSupport.h"
#import "EXTKeyPathCoding.h"
#import "RACCommand.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "UIControl+RACSignalSupport.h"
#import <objc/runtime.h>

static void *UIRefreshControlRACCommandKey = &UIRefreshControlRACCommandKey;
static void *UIRefreshControlDisposableKey = &UIRefreshControlDisposableKey;

@implementation UIRefreshControl (RACCommandSupport)

- (RACCommand *)rac_command {
	return objc_getAssociatedObject(self, UIRefreshControlRACCommandKey);
}

- (void)setRac_command:(RACCommand *)command {
	objc_setAssociatedObject(self, UIRefreshControlRACCommandKey, command, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	// Dispose of any active command associations.
	[objc_getAssociatedObject(self, UIRefreshControlDisposableKey) dispose];

	if (command == nil) return;

	// Like RAC(self, enabled) = command.enabled; but with access to disposable.
	RACDisposable *enabledDisposable = [command.enabled setKeyPath:@keypath(self.enabled) onObject:self];

	RACDisposable *executionDisposable = [[[[self
		rac_signalForControlEvents:UIControlEventValueChanged]
		map:^(UIRefreshControl *x) {
			return [[[command
				execute:x]
				catchTo:[RACSignal empty]]
				then:^{
					return [RACSignal return:x];
				}];
		}]
		concat]
		subscribeNext:^(UIRefreshControl *x) {
			[x endRefreshing];
		}];

	RACDisposable *commandDisposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ enabledDisposable, executionDisposable ]];
	objc_setAssociatedObject(self, UIRefreshControlDisposableKey, commandDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
