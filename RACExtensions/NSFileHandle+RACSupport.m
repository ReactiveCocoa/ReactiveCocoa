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

- (RACSignal *)rac_readInBackground {
	RACReplaySubject *subject = [RACReplaySubject subject];
	[subject setNameWithFormat:@"%@ -rac_readInBackground", self];

	RACSignal *dataNotification = [[[NSNotificationCenter defaultCenter] rac_addObserverForName:NSFileHandleReadCompletionNotification object:self] streamWithMappedValuesFromBlock:^(NSNotification *note) {
		return [note.userInfo objectForKey:NSFileHandleNotificationDataItem];
	}];
	
	__block RACDisposable *subscription = [dataNotification observerWithUpdateHandler:^(NSData *data) {
		if(data.length > 0) {
			[subject didUpdateWithNewValue:data];
			[self readInBackgroundAndNotify];
		} else {
			[subject terminateSubscription];
			[subscription dispose];
		}
	}];
	
	[self readInBackgroundAndNotify];
	
	return subject;
}

@end
