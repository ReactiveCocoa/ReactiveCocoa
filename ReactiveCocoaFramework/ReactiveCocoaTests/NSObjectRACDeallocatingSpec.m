//
//  NSObject+RACDeallocating.m
//  ReactiveCocoa
//
//  Created by Kazuo Koga on 2013/03/15.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACDeallocating.h"
#import "RACTestObject.h"
#import "RACSignal+Operations.h"

SpecBegin(NSObjectRACDeallocatingSpec)

describe(@"-rac_didDeallocSignal", ^{
	it(@"should complete on dealloc", ^{
		__block BOOL completed = NO;
		@autoreleasepool {
			[[[[RACTestObject alloc] init] rac_didDeallocSignal] subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(completed).to.beTruthy();
	});

	it(@"should not send anything", ^{
		__block BOOL valueReceived = NO;
		__block BOOL completed = NO;
		@autoreleasepool {
			[[[[RACTestObject alloc] init] rac_didDeallocSignal] subscribeNext:^(id x) {
				valueReceived = YES;
			} completed:^{
				completed = YES;
			}];
		}

		expect(valueReceived).to.beFalsy();
		expect(completed).to.beTruthy();
	});
});

SpecEnd
