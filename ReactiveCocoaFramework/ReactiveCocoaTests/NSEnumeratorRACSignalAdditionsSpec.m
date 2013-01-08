//
//  NSEnumeratorRACSequenceAdditionsSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSEnumerator+RACSignalAdditions.h"
#import "RACSignal+Operations.h"
#import "RACScheduler.h"

SpecBegin(NSEnumeratorRACSignalAdditions)

describe(@"-rac_signal", ^{
	NSArray *values = @[ @0, @1, @2, @3, @4 ];
	__block RACSignal *signal = nil;
	
	before(^{
		signal = values.objectEnumerator.rac_signal;
	});

	it(@"should send values of the enumerator and then complete", ^{
		NSMutableArray *sentValues = [NSMutableArray array];
		__block BOOL completed = NO;
		
		[signal subscribeNext:^(id x) {
			[sentValues addObject:x];
		} completed:^{
			completed = YES;
		}];
		
		expect(sentValues).will.equal(values);
		expect(completed).will.beTruthy();
	});
	
	it(@"should complete immediately if subscribed to a second time", ^{
		NSMutableArray *sentValues = [NSMutableArray array];
		NSMutableArray *sentValues2 = [NSMutableArray array];
		__block BOOL completed2 = NO;
		
		[signal subscribeNext:^(id x) {
			[sentValues addObject:x];
		}];
		
		[signal subscribeNext:^(id x) {
			[sentValues2 addObject:x];
		} completed:^{
			completed2 = YES;
		}];
		
		expect(sentValues).will.equal(values);
		expect(sentValues2).will.equal(@[]);
		expect(completed2).will.beTruthy();
	});
	
	it(@"should work with -replay", ^{
		NSMutableArray *sentValues = [NSMutableArray array];
		__block BOOL completed = NO;
		NSMutableArray *sentValues2 = [NSMutableArray array];
		__block BOOL completed2 = NO;
		
		RACSignal *replay = [signal replay];
		
		[replay subscribeNext:^(id x) {
			[sentValues addObject:x];
		} completed:^{
			completed = YES;
		}];
		
		[replay subscribeNext:^(id x) {
			[sentValues2 addObject:x];
		} completed:^{
			completed2 = YES;
		}];
		
		expect(sentValues).will.equal(values);
		expect(completed).will.beTruthy();
		expect(sentValues2).will.equal(values);
		expect(completed2).will.beTruthy();
	});
});

describe(@"-rac_signalWithScheduler:", ^{
	NSArray *values = @[ @0, @1, @2, @3, @4 ];
	__block RACScheduler *scheduler = nil;
	__block RACSignal *signal = nil;
	
	before(^{
		scheduler = [RACScheduler scheduler];
		signal = [values.objectEnumerator rac_signalWithScheduler:scheduler];
	});
	
	it(@"should send values on `scheduler`", ^{
		NSMutableArray *sentValues = [NSMutableArray array];
		
		[signal subscribeNext:^(id x) {
			expect(RACScheduler.currentScheduler).will.equal(scheduler);
			[sentValues addObject:x];
		}];
		
		expect(sentValues).will.equal(values);
	});
});

SpecEnd
