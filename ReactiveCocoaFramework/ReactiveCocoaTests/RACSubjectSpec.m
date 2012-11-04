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
#import "RACStashSubject.h"
#import "RACDisposable.h"


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

	it(@"should resend errors", ^{
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];
		[subject sendError:error];

		__block BOOL errorSent = NO;
		[subject subscribeError:^(NSError *sentError) {
			expect(sentError).to.equal(error);
			errorSent = YES;
		}];

		expect(errorSent).to.beTruthy();
	});

	it(@"should resend nil errors", ^{
		[subject sendError:nil];

		__block BOOL errorSent = NO;
		[subject subscribeError:^(NSError *sentError) {
			expect(sentError).to.beNil();
			errorSent = YES;
		}];

		expect(errorSent).to.beTruthy();
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

describe(@"RACStashSubject", ^{
	__block RACStashSubject *subject = nil;
	
	beforeEach(^{
		subject = [RACStashSubject subject];
	});
	
	it(@"should send values received when without subscribers to the first subscriber only", ^{
		id firstValue = @"blah";
		id secondValue = @"more blah";
    id thirdValue = @"lots of blah";
		
		[subject sendNext:firstValue];
		[subject sendNext:secondValue];
    
		__block BOOL firstSubscriberCompleted = NO;
		NSMutableArray *valuesFirstSubscriberReceived = [NSMutableArray array];
		[subject subscribeNext:^(id x) {
			[valuesFirstSubscriberReceived addObject:x];
		} completed:^{
			firstSubscriberCompleted = YES;
		}];    
    
    __block BOOL secondSubscriberCompleted = NO;
    NSMutableArray *valuesSecondSubscriberReceived = [NSMutableArray array];
    [subject subscribeNext:^(id x) {
      [valuesSecondSubscriberReceived addObject:x];
    } completed:^{
      secondSubscriberCompleted = YES;
    }];
				
    [subject sendNext:thirdValue];
		[subject sendCompleted];
    
		expect(valuesFirstSubscriberReceived.count).to.equal(3);
		NSArray *firstExpected = [NSArray arrayWithObjects:firstValue, secondValue, thirdValue, nil];
		expect(valuesFirstSubscriberReceived).to.equal(firstExpected);
		expect(firstSubscriberCompleted).to.beTruthy();
    expect(valuesSecondSubscriberReceived.count).to.equal(1);
    NSArray *secondExpected = [NSArray arrayWithObjects:thirdValue, nil];
    expect(valuesSecondSubscriberReceived).to.equal(secondExpected);
    expect(secondSubscriberCompleted).to.beTruthy();
	});
  
  it(@"should resume stashing values when all subscriptions to it are disposed", ^{
		id firstValue = @"blah";
		id secondValue = @"more blah";
    id thirdValue = @"lots of blah";
    
    NSMutableArray *valuesReceived = [NSMutableArray array];
    
    [subject sendNext:firstValue];
    
    RACDisposable *disposable = [subject subscribeNext:^(id x) {
      [valuesReceived addObject:x];
    }];
    
    [subject sendNext:secondValue];
    [disposable dispose];
    [subject sendNext:thirdValue];
    
    [subject subscribeNext:^(id x) {
      [valuesReceived addObject:x];
    }];
    
    expect(valuesReceived.count).to.equal(3);
    NSArray *expected = [NSArray arrayWithObjects:firstValue, secondValue, thirdValue, nil];
    expect(valuesReceived).to.equal(expected);
  });
});

SpecEnd
