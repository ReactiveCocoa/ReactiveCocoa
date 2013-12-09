//
//  UIRefreshControl+RACSupport.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIRefreshControl+RACSupport.h"
#import "EXTKeyPathCoding.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACDisposable.h"
#import "RACCommand.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACSignalGenerator.h"
#import "UIControl+RACSupport.h"
#import <objc/runtime.h>

@implementation UIRefreshControl (RACSupport)

- (RACSignalGenerator *)rac_refreshGenerator {
	return objc_getAssociatedObject(self, @selector(rac_refreshGenerator));
}

- (void)setRac_refreshGenerator:(RACSignalGenerator *)generator {
	RACSignalGenerator *previousGenerator = self.rac_refreshGenerator;
	if (generator == previousGenerator) return;

	objc_setAssociatedObject(self, @selector(rac_refreshGenerator), generator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	if (generator == nil) {
		[self removeTarget:self action:@selector(rac_refresh:) forControlEvents:UIControlEventValueChanged];
	} else {
		[self addTarget:self action:@selector(rac_refresh:) forControlEvents:UIControlEventValueChanged];
	}
}

- (void)rac_refresh:(id)sender {
	[[[self.rac_refreshGenerator
		signalWithValue:sender]
		catchTo:[RACSignal empty]]
		subscribeCompleted:^{
			[self endRefreshing];
		}];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

static void *UIRefreshControlRACCommandKey = &UIRefreshControlRACCommandKey;
static void *UIRefreshControlDisposableKey = &UIRefreshControlDisposableKey;

@implementation UIRefreshControl (RACSupportDeprecated)

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

#pragma clang diagnostic pop
