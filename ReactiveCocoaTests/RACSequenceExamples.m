//
//  RACSequenceExamples.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSequenceExamples.h"

#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"

NSString * const RACSequenceExamples = @"RACSequenceExamples";
NSString * const RACSequenceExampleSequence = @"RACSequenceExampleSequence";
NSString * const RACSequenceExampleExpectedValues = @"RACSequenceExampleExpectedValues";

SharedExampleGroupsBegin(RACSequenceExamples);

sharedExamplesFor(RACSequenceExamples, ^(NSDictionary *data) {
	__block RACSequence *sequence;
	__block NSArray *values;
	
	beforeEach(^{
		sequence = data[RACSequenceExampleSequence];
		values = [data[RACSequenceExampleExpectedValues] copy];
	});

	it(@"should implement <NSFastEnumeration>", ^{
		NSMutableArray *collectedValues = [NSMutableArray array];
		for (id value in sequence) {
			[collectedValues addObject:value];
		}

		expect(collectedValues).to.equal(values);
	});

	it(@"should return an array", ^{
		expect(sequence.array).to.equal(values);
	});

	describe(@"-signalWithScheduler:", ^{
		it(@"should return an immediately scheduled signal", ^{
			RACSignal *signal = [sequence signalWithScheduler:RACScheduler.immediateScheduler];
			expect(signal.toArray).to.equal(values);
		});

		it(@"should return a background scheduled signal", ^{
			RACSignal *signal = [sequence signalWithScheduler:[RACScheduler scheduler]];
			expect(signal.toArray).to.equal(values);
		});

		it(@"should only evaluate one value per scheduling", ^{
			RACSignal *signal = [sequence signalWithScheduler:RACScheduler.mainThreadScheduler];

			__block BOOL flag = YES;
			__block BOOL completed = NO;
			[signal subscribeNext:^(id x) {
				expect(flag).to.beTruthy();
				flag = NO;

				[RACScheduler.mainThreadScheduler schedule:^{
					// This should get executed before the next value (which
					// verifies that it's YES).
					flag = YES;
				}];
			} completed:^{
				completed = YES;
			}];

			expect(completed).will.beTruthy();
		});
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
	
	it(@"should fold right", ^{
		RACSequence *result = [sequence foldRightWithStart:[RACSequence empty] reduce:^(id first, RACSequence *rest) {
			return [rest.head startWith:first];
		}];
		expect(result.array).to.equal(values);
	});
	
	it(@"should fold left", ^{
		RACSequence *result = [sequence foldLeftWithStart:[RACSequence empty] reduce:^(RACSequence *first, id rest) {
			return [first concat:[RACSequence return:rest]];
		}];
		expect(result.array).to.equal(values);
	});
});

SharedExampleGroupsEnd
