//
//  NSObject+RACDeallocating.m
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACSubject.h"

@implementation NSObject (RACDeallocating)

- (RACSignal *)rac_didDeallocSignal {
	RACSubject *subject = [RACSubject subject];

	[self rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
		[subject sendCompleted];
	}]];

	return subject;
}

@end
