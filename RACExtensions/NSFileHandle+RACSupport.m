//
//  NSFileHandle+RACSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/10/12.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSFileHandle+RACSupport.h"
#import "NSNotificationCenter+RACSupport.h"

@implementation NSFileHandle (RACSupport)

- (RACSubscribable *)rac_readInBackground {
	RACReplaySubject *subject = [RACReplaySubject subject];
	RACSubscribable *dataNotification = [[[NSNotificationCenter defaultCenter] rac_addObserverForName:NSFileHandleReadCompletionNotification object:self] select:^(NSNotification *note) {
		return [note.userInfo objectForKey:NSFileHandleNotificationDataItem];
	}];
	
	__block RACDisposable *subscription = [dataNotification subscribeNext:^(NSData *data) {
		if(data.length > 0) {
			[subject sendNext:data];
			[self readInBackgroundAndNotify];
		} else {
			[subject sendCompleted];
			[subscription dispose];
		}
	}];
	
	[self readInBackgroundAndNotify];
	
	return subject;
}

@end
