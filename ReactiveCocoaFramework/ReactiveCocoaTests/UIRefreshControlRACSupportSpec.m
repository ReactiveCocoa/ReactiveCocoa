//
//  UIRefreshControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-17.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "UIRefreshControl+RACCommandSupport.h"
#import "RACControlCommandExamples.h"
#import "RACCommand.h"

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
});

SpecEnd
