//
//  NSNotificationCenter+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSNotificationCenter+RACSupport.h"

@implementation NSNotificationCenter (RACSupport)

- (RACSubscribable *)rac_addObserverForName:(NSString *)notificationName object:(id)object {
	return [RACSubscribable createSubscribable:^(id<RACSubscriber> subscriber) {
		__block id observer = [self addObserverForName:notificationName object:object queue:nil usingBlock:^(NSNotification *note) {
			[subscriber sendNext:note];
		}];
		
		return [RACDisposable disposableWithBlock:^{
			[[NSNotificationCenter defaultCenter] removeObserver:observer];
		}];
	}];
}

@end
