//
//  RACSequenceExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACSequenceExamples.h"

#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignalProtocol.h"

NSString * const RACSequenceExamples = @"RACSequenceExamples";
NSString * const RACSequenceSequence = @"RACSequenceSequence";
NSString * const RACSequenceExpectedValues = @"RACSequenceExpectedValues";

SharedExampleGroupsBegin(RACSequenceExamples);

sharedExamplesFor(RACSequenceExamples, ^(NSDictionary *data) {
	RACSequence *sequence = data[RACSequenceSequence];
	NSArray *values = [data[RACSequenceExpectedValues] copy];

	it(@"should implement <NSFastEnumeration>", ^{
		NSMutableArray *collectedValues = [NSMutableArray array];
		for (id value in sequence) {
			[collectedValues addObject:value];
		}

		expect(collectedValues).to.equal(values);
	});

	it(@"should return an array", ^{
		expect(sequence.toArray).to.equal(values);
	});

	it(@"should return an immediately scheduled signal", ^{
		id<RACSignal> signal = [sequence signalWithScheduler:RACScheduler.immediateScheduler];
		expect(signal.toArray).to.equal(values);
	});

	it(@"should return a background scheduled signal", ^{
		id<RACSignal> signal = [sequence signalWithScheduler:RACScheduler.backgroundScheduler];
		expect(signal.toArray).to.equal(values);
	});

	it(@"should be equal to itself", ^{
		expect(sequence).to.equal(sequence);
	});

	it(@"should be equal to the same sequence of values", ^{
		RACSequence *newSequence = RACSequence.empty;
		for (id value in values) {
			RACSequence *valueSeq = [RACSequence return:value];
			expect(valueSeq).notTo.beNil();

			newSequence = [newSequence concat:valueSeq];
		}
		
		expect(sequence).to.equal(newSequence);
		expect(sequence.hash).to.equal(newSequence.hash);
	});

	it(@"should not be equal to a different sequence of values", ^{
		RACSequence *anotherSequence = [RACSequence return:@(-1)];
		expect(sequence).notTo.equal(anotherSequence);
	});

	it(@"should return an identical object for -copy", ^{
		expect([sequence copy]).to.beIdenticalTo(sequence);
	});

	it(@"should archive", ^{
		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:sequence];
		expect(data).notTo.beNil();

		RACSequence *unarchived = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		expect(unarchived).to.equal(sequence);
	});
});

SharedExampleGroupsEnd
