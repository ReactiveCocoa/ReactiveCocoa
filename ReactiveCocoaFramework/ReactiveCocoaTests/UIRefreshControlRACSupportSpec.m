//
//  UIRefreshControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIRefreshControl+RACCommandSupport.h"
#import "NSObject+RACSelectorSignal.h"
#import "RACControlCommandExamples.h"
#import "RACCommand.h"
#import "RACSignal.h"

SpecBegin(UIRefreshControlRACSupport)

describe(@"UIRefreshControl", ^{
	__block UIRefreshControl *refreshControl;

	beforeEach(^{
		refreshControl = [[UIRefreshControl alloc] init];
		expect(refreshControl).notTo.beNil();
	});

	itShouldBehaveLike(RACControlCommandExamples, ^{
		return @{
			RACControlCommandExampleControl: refreshControl,
			RACControlCommandExampleActivateBlock: ^(UIRefreshControl *refreshControl) {
				[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
			}
		};
	});

	it(@"should call -endRefreshing", ^{
		refreshControl.rac_command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
			return [RACSignal empty];
		}];

		// Just -rac_signalForSelector: posing as a mock, nothing to see here.
		__block BOOL refreshingEnded = NO;
		[[refreshControl
			rac_signalForSelector:@selector(endRefreshing)]
			subscribeNext:^(id _) {
				refreshingEnded = YES;
			}];

		[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];

		expect(refreshingEnded).will.beTruthy();
	});
});

SpecEnd
