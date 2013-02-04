//
//  RACTupleSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-12-12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACTuple.h"
#import "RACUnit.h"

SpecBegin(RACTuple)

describe(@"RACTupleUnpack", ^{
	it(@"should unpack a single value", ^{
		RACTupleUnpack(RACUnit *value) = [RACTuple tupleWithObjects:RACUnit.defaultUnit, nil];
		expect(value).to.equal(RACUnit.defaultUnit);
	});

	it(@"should translate RACTupleNil", ^{
		RACTupleUnpack(id value) = [RACTuple tupleWithObjects:RACTupleNil.tupleNil, nil];
		expect(value).to.beNil();
	});

	it(@"should unpack multiple values", ^{
		RACTupleUnpack(NSString *str, NSNumber *num) = [RACTuple tupleWithObjects:@"foobar", @5, nil];

		expect(str).to.equal(@"foobar");
		expect(num).to.equal(@5);
	});

	it(@"should fill in missing values with nil", ^{
		RACTupleUnpack(NSString *str, NSNumber *num) = [RACTuple tupleWithObjects:@"foobar", nil];

		expect(str).to.equal(@"foobar");
		expect(num).to.beNil();
	});

	it(@"should skip any values not assigned to", ^{
		RACTupleUnpack(NSString *str, NSNumber *num) = [RACTuple tupleWithObjects:@"foobar", @5, RACUnit.defaultUnit, nil];

		expect(str).to.equal(@"foobar");
		expect(num).to.equal(@5);
	});
});

describe(@"RACTuplePack", ^{
	it(@"should pack a single value", ^{
		expect(RACTuplePack(RACUnit.defaultUnit)).to.equal(([RACTuple tupleWithObjects:RACUnit.defaultUnit, nil]));
	});
	
	it(@"should translate nil", ^{
		expect(RACTuplePack(nil)).to.equal(([RACTuple tupleWithObjects:RACTupleNil.tupleNil, nil]));
	});
	
	it(@"should pack multiple values", ^{
		NSString *string = @"foobar";
		NSNumber *number = @5;
		expect(RACTuplePack(string, number)).to.equal(([RACTuple tupleWithObjects:string, number, nil]));
	});
});

SpecEnd
