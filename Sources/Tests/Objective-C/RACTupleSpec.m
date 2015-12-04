//
//  RACTupleSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-12-12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACTuple.h"
#import "RACUnit.h"

QuickSpecBegin(RACTupleSpec)

qck_describe(@"RACTupleUnpack", ^{
	qck_it(@"should unpack a single value", ^{
		RACTupleUnpack(RACUnit *value) = [RACTuple tupleWithObjects:RACUnit.defaultUnit, nil];
		expect(value).to(equal(RACUnit.defaultUnit));
	});

	qck_it(@"should translate RACTupleNil", ^{
		RACTupleUnpack(id value) = [RACTuple tupleWithObjects:RACTupleNil.tupleNil, nil];
		expect(value).to(beNil());
	});

	qck_it(@"should unpack multiple values", ^{
		RACTupleUnpack(NSString *str, NSNumber *num) = [RACTuple tupleWithObjects:@"foobar", @5, nil];

		expect(str).to(equal(@"foobar"));
		expect(num).to(equal(@5));
	});

	qck_it(@"should fill in missing values with nil", ^{
		RACTupleUnpack(NSString *str, NSNumber *num) = [RACTuple tupleWithObjects:@"foobar", nil];

		expect(str).to(equal(@"foobar"));
		expect(num).to(beNil());
	});

	qck_it(@"should skip any values not assigned to", ^{
		RACTupleUnpack(NSString *str, NSNumber *num) = [RACTuple tupleWithObjects:@"foobar", @5, RACUnit.defaultUnit, nil];

		expect(str).to(equal(@"foobar"));
		expect(num).to(equal(@5));
	});

	qck_it(@"should keep an unpacked value alive when captured in a block", ^{
		__weak id weakPtr = nil;
		id (^block)(void) = nil;

		@autoreleasepool {
			RACTupleUnpack(NSString *str) = [RACTuple tupleWithObjects:[[NSMutableString alloc] init], nil];

			weakPtr = str;
			expect(weakPtr).notTo(beNil());

			block = [^{
				return str;
			} copy];
		}

		expect(weakPtr).notTo(beNil());
		expect(block()).to(equal(weakPtr));
	});
});

qck_describe(@"RACTuplePack", ^{
	qck_it(@"should pack a single value", ^{
		RACTuple *tuple = [RACTuple tupleWithObjects:RACUnit.defaultUnit, nil];
		expect(RACTuplePack(RACUnit.defaultUnit)).to(equal(tuple));
	});
	
	qck_it(@"should translate nil", ^{
		RACTuple *tuple = [RACTuple tupleWithObjects:RACTupleNil.tupleNil, nil];
		expect(RACTuplePack(nil)).to(equal(tuple));
	});
	
	qck_it(@"should pack multiple values", ^{
		NSString *string = @"foobar";
		NSNumber *number = @5;
		RACTuple *tuple = [RACTuple tupleWithObjects:string, number, nil];
		expect(RACTuplePack(string, number)).to(equal(tuple));
	});
});

qck_describe(@"-tupleByAddingObject:", ^{
	__block RACTuple *tuple;

	qck_beforeEach(^{
		tuple = RACTuplePack(@"foo", nil, @"bar");
	});

	qck_it(@"should add a non-nil object", ^{
		RACTuple *newTuple = [tuple tupleByAddingObject:@"buzz"];
		expect(@(newTuple.count)).to(equal(@4));
		expect(newTuple[0]).to(equal(@"foo"));
		expect(newTuple[1]).to(beNil());
		expect(newTuple[2]).to(equal(@"bar"));
		expect(newTuple[3]).to(equal(@"buzz"));
	});

	qck_it(@"should add nil", ^{
		RACTuple *newTuple = [tuple tupleByAddingObject:nil];
		expect(@(newTuple.count)).to(equal(@4));
		expect(newTuple[0]).to(equal(@"foo"));
		expect(newTuple[1]).to(beNil());
		expect(newTuple[2]).to(equal(@"bar"));
		expect(newTuple[3]).to(beNil());
	});

	qck_it(@"should add NSNull", ^{
		RACTuple *newTuple = [tuple tupleByAddingObject:NSNull.null];
		expect(@(newTuple.count)).to(equal(@4));
		expect(newTuple[0]).to(equal(@"foo"));
		expect(newTuple[1]).to(beNil());
		expect(newTuple[2]).to(equal(@"bar"));
		expect(newTuple[3]).to(equal(NSNull.null));
	});
});

QuickSpecEnd
