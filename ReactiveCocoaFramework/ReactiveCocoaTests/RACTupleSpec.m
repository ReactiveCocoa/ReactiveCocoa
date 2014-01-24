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

	it(@"should keep an unpacked value alive when captured in a block", ^{
		__weak id weakPtr = nil;
		id (^block)(void) = nil;

		@autoreleasepool {
			RACTupleUnpack(NSString *str) = [RACTuple tupleWithObjects:[[NSMutableString alloc] init], nil];

			weakPtr = str;
			expect(weakPtr).notTo.beNil();

			block = [^{
				return str;
			} copy];
		}

		expect(weakPtr).notTo.beNil();
		expect(block()).to.equal(weakPtr);
	});
});

describe(@"RACTuplePack", ^{
	it(@"should pack a single value", ^{
		RACTuple *tuple = [RACTuple tupleWithObjects:RACUnit.defaultUnit, nil];
		expect(RACTuplePack(RACUnit.defaultUnit)).to.equal(tuple);
	});
	
	it(@"should translate nil", ^{
		RACTuple *tuple = [RACTuple tupleWithObjects:RACTupleNil.tupleNil, nil];
		expect(RACTuplePack(nil)).to.equal(tuple);
	});
	
	it(@"should pack multiple values", ^{
		NSString *string = @"foobar";
		NSNumber *number = @5;
		RACTuple *tuple = [RACTuple tupleWithObjects:string, number, nil];
		expect(RACTuplePack(string, number)).to.equal(tuple);
	});
});

SpecEnd
