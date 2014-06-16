//
//  UIRefreshControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"
#import "UIRefreshControl+RACSupport.h"

#import "NSObject+RACSelectorSignal.h"
#import "RACAction.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"

SpecBegin(UIRefreshControlRACSupport)

describe(@"UIRefreshControl", ^{
	__block BOOL subscribed;
	__block RACSubject *subject;
	
	__block UIRefreshControl *refreshControl;
	__block BOOL refreshingEnded;

	void (^activate)(UIRefreshControl *) = ^(UIRefreshControl *refreshControl) {
		[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
	};

	beforeEach(^{
		refreshControl = [[UIRefreshControl alloc] init];
		expect(refreshControl).notTo.beNil();

		subject = [RACSubject subject];

		subscribed = NO;
		refreshControl.rac_action = [[RACSignal
			defer:^{
				subscribed = YES;
				return subject;
			}]
			action];

		// Just -rac_signalForSelector: posing as a mock.
		refreshingEnded = NO;
		[[refreshControl
			rac_signalForSelector:@selector(endRefreshing)]
			subscribeNext:^(id _) {
				refreshingEnded = YES;
			}];
	});

	it(@"should call -endRefreshing upon completion", ^{
		activate(refreshControl);
		expect(subscribed).will.beTruthy();
		expect(refreshingEnded).to.beFalsy();

		[subject sendCompleted];
		expect(refreshingEnded).will.beTruthy();
	});

	it(@"should call -endRefreshing upon error", ^{
		activate(refreshControl);
		expect(subscribed).will.beTruthy();
		expect(refreshingEnded).to.beFalsy();

		[subject sendError:[NSError errorWithDomain:@"" code:1 userInfo:nil]];
		expect(refreshingEnded).will.beTruthy();
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: refreshControl,
			RACControlActionExampleActivateBlock: activate
		};
	});
});

SpecEnd
