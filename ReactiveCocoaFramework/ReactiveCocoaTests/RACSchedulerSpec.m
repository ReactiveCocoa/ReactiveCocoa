//
//  RACSchedulerSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/29/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACScheduler.h"

SpecBegin(RACScheduler)

it(@"should know its current scheduler", ^{
	RACScheduler *scheduler = RACScheduler.backgroundScheduler;
	__block RACScheduler *currentScheduler;
	[scheduler schedule:^{
		currentScheduler = RACScheduler.currentScheduler;
	}];

	expect(currentScheduler).willNot.beNil();
	expect(currentScheduler).to.equal(scheduler);

	scheduler = RACScheduler.backgroundScheduler;
	currentScheduler = nil;
	[scheduler schedule:^{
		[RACScheduler.deferredScheduler schedule:^{
			currentScheduler = RACScheduler.currentScheduler;
		}];
	}];

	expect(currentScheduler).willNot.beNil();
	expect(currentScheduler).to.equal(scheduler);
});

SpecEnd
