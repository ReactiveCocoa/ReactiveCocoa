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
	__block UIRefreshControl *refreshControl;

	beforeEach(^{
		refreshControl = [[UIRefreshControl alloc] init];
		expect(refreshControl).notTo.beNil();
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: refreshControl,
			RACControlActionExampleActivateBlock: ^(UIRefreshControl *refreshControl) {
				[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
			}
		};
	});

	describe(@"finishing", ^{
		__block RACSubject *subject;
		__block RACAction *action;

		__block BOOL refreshingEnded;

		beforeEach(^{
			subject = [RACSubject subject];
			action = [subject action];

			refreshControl.rac_action = action;

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
			expect([action.executing first]).will.beTruthy();

			[subject sendCompleted];
			expect([action.executing first]).will.beFalsy();
			expect(refreshingEnded).to.beTruthy();
		});

		it(@"should call -endRefreshing upon error", ^{
			[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
			expect([action.executing first]).will.beTruthy();

			[subject sendError:[NSError errorWithDomain:@"" code:1 userInfo:nil]];
			expect([action.executing first]).will.beFalsy();
			expect(refreshingEnded).to.beTruthy();
		});
	});
});

SpecEnd
