//
//  RACObservableSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#define EXP_SHORTHAND
#import "Specta.h"
#import "Expecta.h"

#import "RACObservableSequence.h"
#import "RACObserver.h"


SpecBegin(RACObservableSequence)

static const NSUInteger capacity = 5;
__block RACObservableSequence *sequence = nil;

describe(@"holding objects", ^{
	beforeEach(^{
		sequence = [RACObservableSequence sequenceWithCapacity:capacity];
	});
	
	it(@"should add a new object", ^{
		id testObject = @"test";
		[sequence addObject:testObject];
		
		expect([sequence lastObject]).toEqual(testObject);
	});
	
	it(@"should accept more objects than its capacity", ^{
		id lastObjectAdded = nil;
		for(NSUInteger i = 0; i < capacity * 2; i++) {
			lastObjectAdded = [NSString stringWithFormat:@"%lu", i];
			[sequence addObject:lastObjectAdded];
		}
		
		expect([sequence lastObject]).toEqual(lastObjectAdded);
	});
});

describe(@"observing", ^{
	beforeEach(^{
		sequence = [RACObservableSequence sequenceWithCapacity:capacity];
	});
	
	it(@"should tell its observer when a new object is added", ^{
		__block BOOL wasNotified = NO;
		[sequence subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
			wasNotified = YES;
		}]];
		 
		[sequence addObject:@"test"];
		
		expect(wasNotified).toBeTruthy();
	});
	
	it(@"should send its observer the object that was added", ^{
		id testObject = @"test";
		[sequence subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
			expect(value).toEqual(testObject);
		}]];
		
		[sequence addObject:testObject];
	});
	
	it(@"should send its observer the last object", ^{
		[sequence subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
			expect([sequence lastObject]).toEqual(value);
		}]];
		
		[sequence addObject:@"test"];
	});
	
	it(@"should support multiple observers", ^{
		__block BOOL was1Notified = NO;
		[sequence subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
			was1Notified = YES;
		}]];
		
		__block BOOL was2Notified = NO;
		[sequence subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) {
			was2Notified = YES;
		}]];
		
		[sequence addObject:@"test"];
		
		expect(was1Notified).toBeTruthy();
		expect(was2Notified).toBeTruthy();
	});
});

describe(@"querying", ^{
	beforeEach(^{
		sequence = [RACObservableSequence sequenceWithCapacity:capacity];
	});
	
	describe(@"where", ^{
		it(@"should pass through the predicate value", ^{
			id predicateValue = @"hi there";
			
			__block BOOL gotPredicateValue = NO;
			[[sequence 
				where:^(id value) { return [value isEqual:predicateValue]; }] 
				subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) { gotPredicateValue = YES; }]];
			
			[sequence addObject:predicateValue];
			
			expect(gotPredicateValue).toBeTruthy();
		});
		
		it(@"shouldn't pass through non-predicate value", ^{
			id predicateValue = @"hi there";
			
			__block BOOL gotPredicateValue = NO;
			[[sequence 
				where:^(id value) { return [value isEqual:predicateValue]; }] 
				subscribe:[RACObserver observerWithCompleted:NULL error:NULL next:^(id value) { gotPredicateValue = YES; }]];
			
			[sequence addObject:@"nyan"];
			
			expect(gotPredicateValue).toBeFalsy();
		});
	});
});

SpecEnd
