//
//  RACSubjectSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 6/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"

#import "RACSubject.h"
#import "RACAsyncSubject.h"
#import "RACBehaviorSubject.h"
#import "RACReplaySubject.h"


SpecBegin(RACSubject)

describe(@"RACAsyncSubject", ^{
	__block RACAsyncSubject *subject = nil;
	
	beforeEach(^{
		subject = [RACAsyncSubject subject];
	});
	
	it(@"should send the last value only at completion", ^{
		id firstValue = @"blah";
		id secondValue = @"more blah";
		
		__block id valueReceived = nil;
		__block NSUInteger nextsReceived = 0;
		[subject subscribeNext:^(id x) {
			valueReceived = x;
			nextsReceived++;
		}];
		
		[subject sendNext:firstValue];
		[subject sendNext:secondValue];
		
		expect(nextsReceived).to.equal(0);
		expect(valueReceived).to.beNil();
		
		[subject sendCompleted];
		
		expect(nextsReceived).to.equal(1);
		expect(valueReceived).to.equal(secondValue);
	});
	
	it(@"should send the last value to new subscribers after completion", ^{
		id firstValue = @"blah";
		id secondValue = @"more blah";
		
		__block id valueReceived = nil;
		__block NSUInteger nextsReceived = 0;
		
		[subject sendNext:firstValue];
		[subject sendNext:secondValue];
		
		expect(nextsReceived).to.equal(0);
		expect(valueReceived).to.beNil();
		
		[subject sendCompleted];
		
		[subject subscribeNext:^(id x) {
			valueReceived = x;
			nextsReceived++;
		}];
		
		expect(nextsReceived).to.equal(1);
		expect(valueReceived).to.equal(secondValue);
	});

	it(@"should not send any values to new subscribers if none were sent originally", ^{
		[subject sendCompleted];

		__block BOOL nextInvoked = NO;
		[subject subscribeNext:^(id x) {
			nextInvoked = YES;
		}];

		expect(nextInvoked).to.beFalsy();
	});
});

describe(@"RACReplaySubject", ^{
	__block RACReplaySubject *subject = nil;
	
	beforeEach(^{
		subject = [RACReplaySubject subject];
	});
	
	it(@"should send both values to new subscribers after completion", ^{
		id firstValue = @"blah";
		id secondValue = @"more blah";
		
		[subject sendNext:firstValue];
		[subject sendNext:secondValue];
		[subject sendCompleted];
		
		__block BOOL completed = NO;
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[subject subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		} completed:^{
			completed = YES;
		}];
		
		expect(valuesReceived.count).to.equal(2);
		NSArray *expected = [NSArray arrayWithObjects:firstValue, secondValue, nil];
		expect(valuesReceived).to.equal(expected);
		expect(completed).to.beTruthy();
	});
});

SpecEnd
