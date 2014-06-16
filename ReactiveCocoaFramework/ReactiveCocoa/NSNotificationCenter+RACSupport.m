//
//  NSNotificationCenter+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSNotificationCenter+RACSupport.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSNotificationCenter (RACSupport)

- (RACSignal *)rac_addObserverForName:(NSString *)notificationName object:(id)object {
	@unsafeify(object);
	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		@strongify(object);
		id observer = [self addObserverForName:notificationName object:object queue:nil usingBlock:^(NSNotification *note) {
			[subscriber sendNext:note];
		}];

		[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
			[self removeObserver:observer];
		}]];
	}] setNameWithFormat:@"-rac_addObserverForName: %@ object: <%@: %p>", notificationName, [object class], object];
}

@end
