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

	describe(@"finishing", ^{
		__block RACSignal *commandSignal;
		__block BOOL refreshingEnded;

		beforeEach(^{
			refreshControl.rac_command = [[RACCommand alloc] initWithSignalBlock:^(id _) {
				return commandSignal;
			}];

			// Just -rac_signalForSelector: posing as a mock.
			refreshingEnded = NO;
			[[refreshControl
				rac_signalForSelector:@selector(endRefreshing)]
				subscribeNext:^(id _) {
					refreshingEnded = YES;
				}];
		});

		it(@"should call -endRefreshing upon completion", ^{
			commandSignal = [RACSignal empty];

			[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
			expect(refreshingEnded).will.beTruthy();
		});

		it(@"should call -endRefreshing upon error", ^{
			commandSignal = [RACSignal error:[NSError errorWithDomain:@"" code:1 userInfo:nil]];

			[refreshControl sendActionsForControlEvents:UIControlEventValueChanged];
			expect(refreshingEnded).will.beTruthy();
		});
	});
});

SpecEnd
