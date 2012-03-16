//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSpecs.h"

#import "RACObservable.h"
#import "RACObservable+Querying.h"
#import "RACObserver.h"


SpecBegin(RACObservable)

describe(@"subscribing", ^{
	__block RACObservable *observable = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		observable = [RACObservable createObservable:^(id<RACObserver> observer) {
			[observer sendNext:nextValueSent];
			[observer sendCompleted];
			return observer;
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
});

describe(@"querying", ^{
	__block RACObservable *observable = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		observable = [RACObservable createObservable:^(id<RACObserver> observer) {
			[observer sendNext:nextValueSent];
			[observer sendCompleted];
			return observer;
		}];
	});
	
	it(@"should support where", ^{
		__block id valueReceived = nil;
		
		[[observable where:^BOOL(id x) {
			return x == nextValueSent;
		}] subscribeNext:^(id x) {
			valueReceived = x;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(valueReceived).toEqual(nextValueSent);
	});
});

describe(@"continuation", ^{
	it(@"shouldn't receive deferred errors", ^{
		RACObservable *observable = [RACObservable createObservable:^(id<RACObserver> observer) {
			[observer sendNext:@"1"];
			[observer sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			[observer sendCompleted];
			return observer;
		}];
		
		__block BOOL gotNext = NO;
		__block BOOL gotError = NO;
		[[observable defer] subscribeNext:^(id x) {
			gotNext = YES;
		} error:^(NSError *error) {
			gotError = YES;
		} completed:^{
			
		}];
		
		expect(gotNext).toBeTruthy();
		expect(gotError).toBeFalsy();
	});
	
	it(@"should repeat after completion", ^{
		RACObservable *observable = [RACObservable createObservable:^(id<RACObserver> observer) {
			[observer sendNext:@"1"];
			[observer sendCompleted];
			[observer sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return observer;
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
