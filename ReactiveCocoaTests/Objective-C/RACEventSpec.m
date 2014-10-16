//
//  RACEventSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-01-07.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACEvent.h"

QuickSpecBegin(RACEventSpec)

qck_it(@"should return the singleton completed event", ^{
	RACEvent *event = RACEvent.completedEvent;
	expect(event).notTo(beNil());

	expect(event).to(beIdenticalTo(RACEvent.completedEvent));
	expect([event copy]).to(beIdenticalTo(event));

	expect(@(event.eventType)).to(equal(@(RACEventTypeCompleted)));
	expect(@(event.finished)).to(beTruthy());
	expect(event.error).to(beNil());
	expect(event.value).to(beNil());
});

qck_it(@"should return an error event", ^{
	NSError *error = [NSError errorWithDomain:@"foo" code:1 userInfo:nil];
	RACEvent *event = [RACEvent eventWithError:error];
	expect(event).notTo(beNil());

	expect(event).to(equal([RACEvent eventWithError:error]));
	expect([event copy]).to(equal(event));

	expect(@(event.eventType)).to(equal(@(RACEventTypeError)));
	expect(@(event.finished)).to(beTruthy());
	expect(event.error).to(equal(error));
	expect(event.value).to(beNil());
});

qck_it(@"should return an error event with a nil error", ^{
	RACEvent *event = [RACEvent eventWithError:nil];
	expect(event).notTo(beNil());

	expect(event).to(equal([RACEvent eventWithError:nil]));
	expect([event copy]).to(equal(event));

	expect(@(event.eventType)).to(equal(@(RACEventTypeError)));
	expect(@(event.finished)).to(beTruthy());
	expect(event.error).to(beNil());
	expect(event.value).to(beNil());
});

qck_it(@"should return a next event", ^{
	NSString *value = @"foo";
	RACEvent *event = [RACEvent eventWithValue:value];
	expect(event).notTo(beNil());

	expect(event).to(equal([RACEvent eventWithValue:value]));
	expect([event copy]).to(equal(event));

	expect(@(event.eventType)).to(equal(@(RACEventTypeNext)));
	expect(@(event.finished)).to(beFalsy());
	expect(event.error).to(beNil());
	expect(event.value).to(equal(value));
});

qck_it(@"should return a next event with a nil value", ^{
	RACEvent *event = [RACEvent eventWithValue:nil];
	expect(event).notTo(beNil());

	expect(event).to(equal([RACEvent eventWithValue:nil]));
	expect([event copy]).to(equal(event));

	expect(@(event.eventType)).to(equal(@(RACEventTypeNext)));
	expect(@(event.finished)).to(beFalsy());
	expect(event.error).to(beNil());
	expect(event.value).to(beNil());
});

QuickSpecEnd
