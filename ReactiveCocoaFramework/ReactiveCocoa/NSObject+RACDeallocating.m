//
//  NSObject+RACDeallocating.m
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACDeallocating.h"
#import "RACSubject.h"
#import <objc/runtime.h>

@interface rac_RACDeallocTracker : NSObject
@property (nonatomic) RACSubject *subject;
@end

@implementation rac_RACDeallocTracker

- (void)dealloc {
	[_subject sendCompleted];
}

@end

@implementation NSObject (RACDeallocating)

- (RACSignal *)rac_didDeallocSignal {
	RACSubject *subject = [RACSubject subject];

	rac_RACDeallocTracker *tracker = [[rac_RACDeallocTracker alloc] init];
	tracker.subject = subject;

	// make retain chain: self -> tracker -> subject.
	objc_setAssociatedObject(self, (__bridge CFTypeRef)tracker, tracker,
		OBJC_ASSOCIATION_RETAIN_NONATOMIC);

	return subject;
}

@end
