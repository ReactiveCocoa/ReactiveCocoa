//
//  RACSubscriberSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-27.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSubscriberExamples.h"

#import "RACSubscriber.h"

SpecBegin(RACSubscriber)

__block RACSubscriber *subscriber;
__block NSMutableSet *values;

__block BOOL success;
__block NSError *error;

beforeEach(^{
	values = [NSMutableSet set];

	success = YES;
	error = nil;

	subscriber = [RACSubscriber subscriberWithNext:^(id value) {
		[values addObject:value];
	} error:^(NSError *e) {
		error = e;
		success = NO;
	} completed:^{
		success = YES;
	}];
});

itShouldBehaveLike(RACSubscriberExamples, [^{ return subscriber; } copy], [^(NSSet *expectedValues) {
	expect(success).to.beTruthy();
	expect(error).to.beNil();
	expect(values).to.equal(expectedValues);
} copy], nil);

SpecEnd
