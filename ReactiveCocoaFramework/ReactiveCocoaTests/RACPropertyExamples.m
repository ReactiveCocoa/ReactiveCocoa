//
//  RACPropertyExamples.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertyExamples.h"
#import "RACProperty.h"

NSString * const RACPropertyExamples = @"RACPropertyExamples";

SharedExampleGroupsBegin(RACPropertyExamples)

sharedExamplesFor(RACPropertyExamples, ^(RACProperty *(^getProperty)(void)) {
	__block RACProperty *property;
	id value1 = @"test value 1";
	id value2 = @"test value 2";
	id value3 = @"test value 3";
	NSArray *values = @[ value1, value2, value3 ];
	
	before(^{
		property = getProperty();
		expect(property).notTo.beNil();
	});
	
	it(@"should send it's current value on subscription", ^{
		__block id receivedValue = nil;
		[property sendNext:value1];
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value1);
		
		[property sendNext:value2];
		[[property take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value2);
	});
	
	it(@"should send it's value as it changes", ^{
		[property sendNext:value1];
		NSMutableArray *receivedValues = [NSMutableArray array];
		[property subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		[property sendNext:value2];
		[property sendNext:value3];
		expect(receivedValues).to.equal(values);
	});
	
});

SharedExampleGroupsEnd
