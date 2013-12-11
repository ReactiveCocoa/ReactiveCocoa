//
//  UIRefreshControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIRefreshControl+RACSupport.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACDynamicSignalGenerator.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

SpecBegin(UIRefreshControlRACSupport)

describe(@"UIRefreshControl", ^{
	__block UIRefreshControl *refreshControl;

	__block RACSubject *subject;
	__block RACSignalGenerator *generator;

	__block BOOL refreshingEnded;

	beforeEach(^{
		refreshControl = [[UIRefreshControl alloc] init];
		expect(refreshControl).notTo.beNil();

		subject = [RACSubject subject];
		generator = [RACDynamicSignalGenerator generatorWithBlock:^(id _) {
			return subject;
		}];

		refreshControl.rac_refreshGenerator = generator;

		// Just -rac_signalForSelector: posing as a mock.
		refreshingEnded = NO;
		[[refreshControl
			rac_signalForSelector:@selector(endRefreshing)]
			subscribeNext:^(id _) {
				refreshingEnded = YES;
			}];
	});

	it(@"should call -endRefreshing upon completion", ^{
		[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
		expect(refreshingEnded).to.beFalsy();

		[subject sendCompleted];
		expect(refreshingEnded).to.beTruthy();
	});

	it(@"should call -endRefreshing upon error", ^{
		[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
		expect(refreshingEnded).to.beFalsy();

		[subject sendError:[NSError errorWithDomain:@"" code:1 userInfo:nil]];
		expect(refreshingEnded).to.beTruthy();
	});
});

SpecEnd
