//
//  RACValueSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/7/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSpecs.h"
#import "RACValue.h"
#import "RACSequence+Private.h"


SpecBegin(RACValue)

describe(@"behavior", ^{
	__block RACValue *value = nil;
	
	beforeEach(^{
		value = [RACValue value];
	});
	
	it(@"should have the value of its most recently added object", ^{
		id obj = @"blah";
		[value addObject:obj];
		
		expect(value.value).toEqual(obj);
	});
	
	it(@"should return nil for value after adding nil", ^{
		[value addObject:@"blah"];
		[value addObject:@"something else"];
		[value addObjectAndNilsAreOK:nil];
		
		expect(value.value).toBeNil();
	});
	
	it(@"should return nil for its last object after adding nil", ^{
		[value addObject:@"blah"];
		[value addObject:@"something else"];
		[value addObjectAndNilsAreOK:nil];
		
		expect([value lastObject]).toBeNil();
	});
});

SpecEnd
