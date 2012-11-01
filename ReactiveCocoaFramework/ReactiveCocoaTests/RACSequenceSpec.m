//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"

#import "RACSequence.h"
#import "RACUnit.h"

SpecBegin(RACSequence)

describe(@"<RACStream>", ^{
	it(@"should return an empty sequence", ^{
		RACSequence *sequence = RACSequence.empty;
		expect(sequence).notTo.beNil();
		expect(sequence.head).to.beNil();
		expect(sequence.tail).to.beNil();
	});

	it(@"should lift a value into a sequence", ^{
		RACSequence *sequence = [RACSequence return:RACUnit.defaultUnit];
		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(RACUnit.defaultUnit);
		expect(sequence.tail).to.beNil();
	});

	it(@"should concatenate two sequences", ^{
		RACSequence *sequence = [[RACSequence return:@0] concat:[RACSequence return:@1]];
		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(@0);
		expect(sequence.tail).notTo.beNil();

		expect(sequence.tail.head).to.equal(@1);
		expect(sequence.tail.tail).to.beNil();
	});

	it(@"should concatenate three sequences", ^{
		RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(@0);
		expect(sequence.tail).notTo.beNil();

		expect(sequence.tail.head).to.equal(@1);
		expect(sequence.tail.tail).notTo.beNil();

		expect(sequence.tail.tail.head).to.equal(@2);
		expect(sequence.tail.tail.tail).to.beNil();
	});

	it(@"should return the result of binding a single value", ^{
		RACSequence *sequence = [[RACSequence return:@0] bind:^(NSNumber *value) {
			NSNumber *newValue = @(value.integerValue + 1);
			return [RACSequence return:newValue];
		}];

		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(@1);
		expect(sequence.tail).to.beNil();
	});

	it(@"should flatten", ^{
		RACSequence *sequence = [RACSequence return:[RACSequence return:RACUnit.defaultUnit]].flatten;
		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(RACUnit.defaultUnit);
		expect(sequence.tail).to.beNil();
	});

	it(@"should concatenate the result of binding multiple values", ^{
		RACSequence *baseSequence = [[RACSequence return:@0] concat:[RACSequence return:@1]];
		RACSequence *sequence = [baseSequence bind:^(NSNumber *value) {
			NSNumber *newValue = @(value.integerValue + 1);
			return [RACSequence return:newValue];
		}];

		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(@1);
		expect(sequence.tail).notTo.beNil();
		expect(sequence.tail.head).to.equal(@2);
		expect(sequence.tail.tail).to.beNil();
	});

	it(@"should map", ^{
		RACSequence *baseSequence = [[RACSequence return:@0] concat:[RACSequence return:@1]];
		RACSequence *sequence = [baseSequence map:^(NSNumber *value) {
			return @(value.integerValue + 1);
		}];

		expect(sequence).notTo.beNil();
		expect(sequence.head).to.equal(@1);
		expect(sequence.tail).notTo.beNil();
		expect(sequence.tail.head).to.equal(@2);
		expect(sequence.tail.tail).to.beNil();
	});
});

SpecEnd
