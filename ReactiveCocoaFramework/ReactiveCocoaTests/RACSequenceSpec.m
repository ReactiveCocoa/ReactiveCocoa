//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSequenceExamples.h"
#import "RACStreamExamples.h"

#import "RACDisposable.h"
#import "RACSequence.h"
#import "RACUnit.h"
#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACPropertySubscribing.h"

SpecBegin(RACSequence)

describe(@"RACStream", ^{
	id verifyValues = ^(RACSequence *sequence, NSArray *expectedValues) {
		NSMutableArray *collectedValues = [NSMutableArray array];
		while (sequence.head != nil) {
			[collectedValues addObject:sequence.head];
			sequence = sequence.tail;
		}

		expect(collectedValues).to.equal(expectedValues);
	};

	__block RACSequence *infiniteSequence = [RACSequence sequenceWithHeadBlock:^{
		return RACUnit.defaultUnit;
	} tailBlock:^{
		return infiniteSequence;
	}];

	itShouldBehaveLike(RACStreamExamples, ^{
		return @{
			RACStreamExamplesClass: RACSequence.class,
			RACStreamExamplesVerifyValuesBlock: verifyValues,
			RACStreamExamplesInfiniteStream: infiniteSequence
		};
	});
});

describe(@"+sequenceWithHeadBlock:tailBlock:", ^{
	__block RACSequence *sequence;
	__block BOOL headInvoked;
	__block BOOL tailInvoked;

	before(^{
		headInvoked = NO;
		tailInvoked = NO;

		sequence = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return @0;
		} tailBlock:^{
			tailInvoked = YES;
			return [RACSequence return:@1];
		}];

		expect(sequence).notTo.beNil();
	});

	it(@"should use the values from the head and tail blocks", ^{
		expect(sequence.head).to.equal(@0);
		expect(sequence.tail.head).to.equal(@1);
		expect(sequence.tail.tail).to.beNil();
	});

	it(@"should lazily invoke head and tail blocks", ^{
		expect(headInvoked).to.beFalsy();
		expect(tailInvoked).to.beFalsy();

		expect(sequence.head).to.equal(@0);
		expect(headInvoked).to.beTruthy();
		expect(tailInvoked).to.beFalsy();

		expect(sequence.tail).notTo.beNil();
		expect(tailInvoked).to.beTruthy();
	});

	after(^{
		itShouldBehaveLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: @[ @0, @1 ]
			};
		});
	});
});

describe(@"empty sequences", ^{
	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: [RACSequence empty],
			RACSequenceExampleExpectedValues: @[]
		};
	});
});

describe(@"non-empty sequences", ^{
	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]],
			RACSequenceExampleExpectedValues: @[ @0, @1, @2 ]
		};
	});
});

describe(@"eager sequences", ^{
	__block RACSequence *lazySequence;
	__block BOOL headInvoked;
	__block BOOL tailInvoked;

	NSArray *values = @[ @0, @1 ];
	
	before(^{
		headInvoked = NO;
		tailInvoked = NO;
		
		lazySequence = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return @0;
		} tailBlock:^{
			tailInvoked = YES;
			return [RACSequence return:@1];
		}];
		
		expect(lazySequence).notTo.beNil();
	});
	
	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: lazySequence.eagerSequence,
			RACSequenceExampleExpectedValues: values
		};
	});
	
	it(@"should evaluate all values immediately", ^{
		RACSequence *eagerSequence = lazySequence.eagerSequence;
		expect(headInvoked).to.beTruthy();
		expect(tailInvoked).to.beTruthy();
		expect(eagerSequence.array).to.equal(values);
	});
});

describe(@"-take:", ^{
	it(@"should complete take: without needing the head of the second item in the sequence", ^{
		__block NSUInteger valuesTaken = 0;

		__block RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^{
			++valuesTaken;
			return RACUnit.defaultUnit;
		} tailBlock:^{
			return sequence;
		}];

		NSArray *values = [sequence take:1].array;
		expect(values).to.equal(@[ RACUnit.defaultUnit ]);
		expect(valuesTaken).to.equal(1);
	});
});

describe(@"-bind:", ^{
	it(@"should only evaluate head when the resulting sequence is evaluated", ^{
		__block BOOL headInvoked = NO;

		RACSequence *original = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return RACUnit.defaultUnit;
		} tailBlock:^ id {
			return nil;
		}];

		RACSequence *bound = [original bind:^{
			return ^(id value, BOOL *stop) {
				return [RACSequence return:value];
			};
		}];

		expect(bound).notTo.beNil();
		expect(headInvoked).to.beFalsy();

		expect(bound.head).to.equal(RACUnit.defaultUnit);
		expect(headInvoked).to.beTruthy();
	});
});

describe(@"-objectEnumerator", ^{
	it(@"should only evaluate head as it's enumerated", ^{
		__block BOOL firstHeadInvoked = NO;
		__block BOOL secondHeadInvoked = NO;
		__block BOOL thirdHeadInvoked = NO;
		
		RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^id{
			firstHeadInvoked = YES;
			return @1;
		} tailBlock:^RACSequence *{
			return [RACSequence sequenceWithHeadBlock:^id{
				secondHeadInvoked = YES;
				return @2;
			} tailBlock:^RACSequence *{
				return [RACSequence sequenceWithHeadBlock:^id{
					thirdHeadInvoked = YES;
					return @3;
				} tailBlock:^RACSequence *{
					return RACSequence.empty;
				}];
			}];
		}];
		NSEnumerator *enumerator = sequence.objectEnumerator;
		
		expect(firstHeadInvoked).to.beFalsy();
		expect(secondHeadInvoked).to.beFalsy();
		expect(thirdHeadInvoked).to.beFalsy();
		
		expect([enumerator nextObject]).to.equal(@1);
		
		expect(firstHeadInvoked).to.beTruthy();
		expect(secondHeadInvoked).to.beFalsy();
		expect(thirdHeadInvoked).to.beFalsy();
		
		expect([enumerator nextObject]).to.equal(@2);
		
		expect(secondHeadInvoked).to.beTruthy();
		expect(thirdHeadInvoked).to.beFalsy();
		
		expect([enumerator nextObject]).to.equal(@3);
		
		expect(thirdHeadInvoked).to.beTruthy();
		
		expect([enumerator nextObject]).to.beNil();
	});
	
	it(@"should let the sequence dealloc as it's enumerated", ^{
		__block BOOL firstSequenceDeallocd = NO;
		__block BOOL secondSequenceDeallocd = NO;
		__block BOOL thirdSequenceDeallocd = NO;
		
		NSEnumerator *enumerator = nil;
		
		@autoreleasepool {
			RACSequence *thirdSequence __attribute__((objc_precise_lifetime)) = [RACSequence sequenceWithHeadBlock:^id{
				return @3;
			} tailBlock:^RACSequence *{
				return RACSequence.empty;
			}];
			[thirdSequence rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				thirdSequenceDeallocd = YES;
			}]];
			
			RACSequence *secondSequence __attribute__((objc_precise_lifetime)) = [RACSequence sequenceWithHeadBlock:^id{
				return @2;
			} tailBlock:^RACSequence *{
				return thirdSequence;
			}];
			[secondSequence rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				secondSequenceDeallocd = YES;
			}]];
			
			RACSequence *firstSequence __attribute__((objc_precise_lifetime)) = [RACSequence sequenceWithHeadBlock:^id{
				return @1;
			} tailBlock:^RACSequence *{
				return secondSequence;
			}];
			[firstSequence rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				firstSequenceDeallocd = YES;
			}]];
			
			enumerator = firstSequence.objectEnumerator;
		}
		
		@autoreleasepool {
			expect([enumerator nextObject]).to.equal(@1);
		}

		@autoreleasepool {
			expect([enumerator nextObject]).to.equal(@2);
		}
		expect(firstSequenceDeallocd).will.beTruthy();
		
		@autoreleasepool {
			expect([enumerator nextObject]).to.equal(@3);
		}
		expect(secondSequenceDeallocd).will.beTruthy();
		
		@autoreleasepool {
			expect([enumerator nextObject]).to.beNil();
		}
		expect(thirdSequenceDeallocd).will.beTruthy();
	});
});

it(@"shouldn't overflow the stack when deallocated on a background queue", ^{
	NSUInteger length = 10000;
	NSMutableArray *values = [NSMutableArray arrayWithCapacity:length];
	for (NSUInteger i = 0; i < length; ++i) {
		[values addObject:@(i)];
	}

	__block BOOL finished = NO;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@autoreleasepool {
			[[values.rac_sequence map:^(id value) {
				return value;
			}] array];
		}

		finished = YES;
	});

	NSTimeInterval oldTimeout = Expecta.asynchronousTestTimeout;
	Expecta.asynchronousTestTimeout = DBL_MAX;
	expect(finished).will.beTruthy();
	Expecta.asynchronousTestTimeout = oldTimeout;
});

SpecEnd
