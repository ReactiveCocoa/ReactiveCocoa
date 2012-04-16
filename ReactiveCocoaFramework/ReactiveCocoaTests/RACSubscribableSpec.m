//
//  RACSubscribableSpc.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"

#import "RACSubscribable.h"
#import "RACSubscribable+Operations.h"
#import "RACSubscriber.h"
#import "RACSubject.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"


SpecBegin(RACSubscribable)

describe(@"subscribing", ^{
	__block RACSubscribable *observable = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		observable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
			[observer sendNext:nextValueSent];
			[observer sendCompleted];
			return nil;
		}];
	});
	
	it(@"should get next values", ^{
		__block id nextValueReceived = nil;
		[observable subscribeNext:^(id x) {
			nextValueReceived = x;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(nextValueReceived).toEqual(nextValueSent);
	});
	
	it(@"should get completed", ^{
		__block BOOL didGetCompleted = NO;
		[observable subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			
		} completed:^{
			didGetCompleted = YES;
		}];
		
		expect(didGetCompleted).toBeTruthy();
	});
	
	it(@"should not get an error", ^{
		__block BOOL didGetError = NO;
		[observable subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			didGetError = YES;
		} completed:^{
			
		}];
		
		expect(didGetError).toBeFalsy();
	});
	
	it(@"shouldn't get anything after dispose", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACDisposable *disposable = [subject subscribeNext:^(id x) {
			expect(shouldBeGettingItems).toBeTruthy();
		}];
		
		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];
		
		[disposable dispose];
		
		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});
});

describe(@"querying", ^{
	__block RACSubscribable *observable = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		observable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
			[observer sendNext:nextValueSent];
			[observer sendNext:@"other value"];
			[observer sendCompleted];
			return nil;
		}];
	});
	
	it(@"should support where", ^{
		__block BOOL didGetCallbacks = NO;
		[[observable where:^BOOL(id x) {
			return x == nextValueSent;
		}] subscribeNext:^(id x) {
			expect(x).toEqual(nextValueSent);
			didGetCallbacks = YES;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(didGetCallbacks).toBeTruthy();
	});
	
	it(@"should support select", ^{
		__block BOOL didGetCallbacks = NO;
		id transformedValue = @"other";
		[[observable select:^(id x) {			
			return transformedValue;
		}] subscribeNext:^(id x) {
			expect(x).toEqual(transformedValue);
			didGetCallbacks = YES;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(didGetCallbacks).toBeTruthy();
	});
	
	it(@"should support window", ^{
		RACSubscribable *observable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
			[observer sendNext:@"1"];
			[observer sendNext:@"2"];
			[observer sendNext:@"3"];
			[observer sendNext:@"4"];
			[observer sendNext:@"5"];
			[observer sendCompleted];
			return nil;
		}];
		
		RACBehaviorSubject *windowOpen = [RACBehaviorSubject behaviorSubjectWithDefaultValue:@""];
		
		RACSubject *closeSubject = [RACSubject subject];
		__block NSUInteger valuesReceived = 0;
		
		RACSubscribable *window = [observable windowWithStart:windowOpen close:^(id<RACSubscribable> start) {
			return closeSubject;
		}];
				
		[window subscribeNext:^(id x) {			
			[x subscribeNext:^(id x) {
				valuesReceived++;
				NSLog(@"got: %@", x);
				
				if(valuesReceived % 2 == 0) {
					[closeSubject sendNext:x];
					[windowOpen sendNext:@""];
				}
			} error:^(NSError *error) {
				
			} completed:^{
				
			}];
		} error:^(NSError *error) {
			
		} completed:^{
			NSLog(@"completed");
		}];
	});
	
	it(@"should support take", ^{
		@autoreleasepool {
			RACSubscribable *observable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
				[observer sendNext:@"1"];
				[observer sendNext:@"2"];
				[observer sendNext:@"3"];
				[observer sendNext:@"4"];
				[observer sendNext:@"5"];
				[observer sendCompleted];
				return nil;
			}];
			
			RACSubscriber *ob = [RACSubscriber subscriberWithNext:NULL error:NULL completed:NULL];
			
			@autoreleasepool {
				[observable subscribe:ob];
			}
			
			NSLog(@"d");
		}
	});
});

describe(@"continuation", ^{
	it(@"shouldn't receive deferred errors", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACSubscribable *observable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
			if(numberOfSubscriptions > 2) {
				[observer sendCompleted];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[observer sendNext:@"1"];
			[observer sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			[observer sendCompleted];
			return nil;
		}];
		
		__block BOOL gotNext = NO;
		__block BOOL gotError = NO;
		[[observable catchToMaybe] subscribeNext:^(id x) {
			gotNext = YES;
		} error:^(NSError *error) {
			gotError = YES;
		} completed:^{
			
		}];
		
		expect(gotNext).toBeTruthy();
		expect(gotError).toBeFalsy();
	});
	
	it(@"should repeat after completion", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACSubscribable *observable = [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
			if(numberOfSubscriptions > 2) {
				[observer sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[observer sendNext:@"1"];
			[observer sendCompleted];
			[observer sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return nil;
		}];
		
		__block NSUInteger nextCount = 0;
		__block BOOL gotCompleted = NO;
		[[observable repeat] subscribeNext:^(id x) {
			nextCount++;
		} error:^(NSError *error) {
			
		} completed:^{
			gotCompleted = YES;
		}];
		
		expect(nextCount).toBeGreaterThan(1);
		expect(gotCompleted).toBeFalsy();
	});
});

SpecEnd
