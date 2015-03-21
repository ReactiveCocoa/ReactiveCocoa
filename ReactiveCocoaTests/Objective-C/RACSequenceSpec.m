//
//  RACSequenceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-01.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACSequenceExamples.h"
#import "RACStreamExamples.h"

#import "NSArray+RACSequenceAdditions.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSequence.h"
#import "RACUnit.h"

QuickSpecBegin(RACSequenceSpec)

qck_describe(@"RACStream", ^{
	id verifyValues = ^(RACSequence *sequence, NSArray *expectedValues) {
		NSMutableArray *collectedValues = [NSMutableArray array];
		while (sequence.head != nil) {
			[collectedValues addObject:sequence.head];
			sequence = sequence.tail;
		}

		expect(collectedValues).to(equal(expectedValues));
	};

	__block RACSequence *infiniteSequence = [RACSequence sequenceWithHeadBlock:^{
		return RACUnit.defaultUnit;
	} tailBlock:^{
		return infiniteSequence;
	}];

	qck_itBehavesLike(RACStreamExamples, ^{
		return @{
			RACStreamExamplesClass: RACSequence.class,
			RACStreamExamplesVerifyValuesBlock: verifyValues,
			RACStreamExamplesInfiniteStream: infiniteSequence
		};
	});
});

qck_describe(@"+sequenceWithHeadBlock:tailBlock:", ^{
	__block RACSequence *sequence;
	__block BOOL headInvoked;
	__block BOOL tailInvoked;

	qck_beforeEach(^{
		headInvoked = NO;
		tailInvoked = NO;

		sequence = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return @0;
		} tailBlock:^{
			tailInvoked = YES;
			return [RACSequence return:@1];
		}];

		expect(sequence).notTo(beNil());
	});

	qck_it(@"should use the values from the head and tail blocks", ^{
		expect(sequence.head).to(equal(@0));
		expect(sequence.tail.head).to(equal(@1));
		expect(sequence.tail.tail).to(beNil());
	});

	qck_it(@"should lazily invoke head and tail blocks", ^{
		expect(@(headInvoked)).to(beFalsy());
		expect(@(tailInvoked)).to(beFalsy());

		expect(sequence.head).to(equal(@0));
		expect(@(headInvoked)).to(beTruthy());
		expect(@(tailInvoked)).to(beFalsy());

		expect(sequence.tail).notTo(beNil());
		expect(@(tailInvoked)).to(beTruthy());
	});

	qck_afterEach(^{
		qck_itBehavesLike(RACSequenceExamples, ^{
			return @{
				RACSequenceExampleSequence: sequence,
				RACSequenceExampleExpectedValues: @[ @0, @1 ]
			};
		});
	});
});

qck_describe(@"empty sequences", ^{
	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: [RACSequence empty],
			RACSequenceExampleExpectedValues: @[]
		};
	});
});

qck_describe(@"non-empty sequences", ^{
	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]],
			RACSequenceExampleExpectedValues: @[ @0, @1, @2 ]
		};
	});
});

qck_describe(@"eager sequences", ^{
	__block RACSequence *lazySequence;
	__block BOOL headInvoked;
	__block BOOL tailInvoked;

	NSArray *values = @[ @0, @1 ];
	
	qck_beforeEach(^{
		headInvoked = NO;
		tailInvoked = NO;
		
		lazySequence = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return @0;
		} tailBlock:^{
			tailInvoked = YES;
			return [RACSequence return:@1];
		}];
		
		expect(lazySequence).notTo(beNil());
	});
	
	qck_itBehavesLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: lazySequence.eagerSequence,
			RACSequenceExampleExpectedValues: values
		};
	});
	
	qck_it(@"should evaluate all values immediately", ^{
		RACSequence *eagerSequence = lazySequence.eagerSequence;
		expect(@(headInvoked)).to(beTruthy());
		expect(@(tailInvoked)).to(beTruthy());
		expect(eagerSequence.array).to(equal(values));
	});
});

qck_describe(@"-take:", ^{
	qck_it(@"should complete take: without needing the head of the second item in the sequence", ^{
		__block NSUInteger valuesTaken = 0;

		__block RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^{
			++valuesTaken;
			return RACUnit.defaultUnit;
		} tailBlock:^{
			return sequence;
		}];

		NSArray *values = [sequence take:1].array;
		expect(values).to(equal(@[ RACUnit.defaultUnit ]));
		expect(@(valuesTaken)).to(equal(@1));
	});
});

qck_describe(@"-bind:", ^{
	qck_it(@"should only evaluate head when the resulting sequence is evaluated", ^{
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

		expect(bound).notTo(beNil());
		expect(@(headInvoked)).to(beFalsy());

		expect(bound.head).to(equal(RACUnit.defaultUnit));
		expect(@(headInvoked)).to(beTruthy());
	});
});

qck_describe(@"-objectEnumerator", ^{
	qck_it(@"should only evaluate head as it's enumerated", ^{
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
		
		expect(@(firstHeadInvoked)).to(beFalsy());
		expect(@(secondHeadInvoked)).to(beFalsy());
		expect(@(thirdHeadInvoked)).to(beFalsy());
		
		expect([enumerator nextObject]).to(equal(@1));
		
		expect(@(firstHeadInvoked)).to(beTruthy());
		expect(@(secondHeadInvoked)).to(beFalsy());
		expect(@(thirdHeadInvoked)).to(beFalsy());
		
		expect([enumerator nextObject]).to(equal(@2));
		
		expect(@(secondHeadInvoked)).to(beTruthy());
		expect(@(thirdHeadInvoked)).to(beFalsy());
		
		expect([enumerator nextObject]).to(equal(@3));
		
		expect(@(thirdHeadInvoked)).to(beTruthy());
		
		expect([enumerator nextObject]).to(beNil());
	});
	
	qck_it(@"should let the sequence dealloc as it's enumerated", ^{
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
			[thirdSequence.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				thirdSequenceDeallocd = YES;
			}]];
			
			RACSequence *secondSequence __attribute__((objc_precise_lifetime)) = [RACSequence sequenceWithHeadBlock:^id{
				return @2;
			} tailBlock:^RACSequence *{
				return thirdSequence;
			}];
			[secondSequence.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				secondSequenceDeallocd = YES;
			}]];
			
			RACSequence *firstSequence __attribute__((objc_precise_lifetime)) = [RACSequence sequenceWithHeadBlock:^id{
				return @1;
			} tailBlock:^RACSequence *{
				return secondSequence;
			}];
			[firstSequence.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				firstSequenceDeallocd = YES;
			}]];
			
			enumerator = firstSequence.objectEnumerator;
		}
		
		@autoreleasepool {
			expect([enumerator nextObject]).to(equal(@1));
		}

		@autoreleasepool {
			expect([enumerator nextObject]).to(equal(@2));
		}
		expect(@(firstSequenceDeallocd)).toEventually(beTruthy());
		
		@autoreleasepool {
			expect([enumerator nextObject]).to(equal(@3));
		}
		expect(@(secondSequenceDeallocd)).toEventually(beTruthy());
		
		@autoreleasepool {
			expect([enumerator nextObject]).to(beNil());
		}
		expect(@(thirdSequenceDeallocd)).toEventually(beTruthy());
	});
});

qck_it(@"shouldn't overflow the stack when deallocated on a background queue", ^{
	NSUInteger length = 10000;
	NSMutableArray *values = [NSMutableArray arrayWithCapacity:length];
	for (NSUInteger i = 0; i < length; ++i) {
		[values addObject:@(i)];
	}

	__block BOOL finished = NO;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@autoreleasepool {
			(void)[[values.rac_sequence map:^(id value) {
				return value;
			}] array];
		}

		finished = YES;
	});

	expect(@(finished)).toEventually(beTruthy());
});

qck_describe(@"-foldLeftWithStart:reduce:", ^{
	qck_it(@"should reduce with start first", ^{
		RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
		NSNumber *result = [sequence foldLeftWithStart:@3 reduce:^(NSNumber *first, NSNumber *rest) {
			return first;
		}];
		expect(result).to(equal(@3));
	});

	qck_it(@"should be left associative", ^{
		RACSequence *sequence = [[[RACSequence return:@1] concat:[RACSequence return:@2]] concat:[RACSequence return:@3]];
		NSNumber *result = [sequence foldLeftWithStart:@0 reduce:^(NSNumber *first, NSNumber *rest) {
			int difference = first.intValue - rest.intValue;
			return @(difference);
		}];
		expect(result).to(equal(@-6));
	});
});

qck_describe(@"-foldRightWithStart:reduce:", ^{
	qck_it(@"should be lazy", ^{
		__block BOOL headInvoked = NO;
		__block BOOL tailInvoked = NO;
		RACSequence *sequence = [RACSequence sequenceWithHeadBlock:^{
			headInvoked = YES;
			return @0;
		} tailBlock:^{
			tailInvoked = YES;
			return [RACSequence return:@1];
		}];
		
		NSNumber *result = [sequence foldRightWithStart:@2 reduce:^(NSNumber *first, RACSequence *rest) {
			return first;
		}];
		
		expect(result).to(equal(@0));
		expect(@(headInvoked)).to(beTruthy());
		expect(@(tailInvoked)).to(beFalsy());
	});
	
	qck_it(@"should reduce with start last", ^{
		RACSequence *sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
		NSNumber *result = [sequence foldRightWithStart:@3 reduce:^(NSNumber *first, RACSequence *rest) {
			return rest.head;
		}];
		expect(result).to(equal(@3));
	});
	
	qck_it(@"should be right associative", ^{
		RACSequence *sequence = [[[RACSequence return:@1] concat:[RACSequence return:@2]] concat:[RACSequence return:@3]];
		NSNumber *result = [sequence foldRightWithStart:@0 reduce:^(NSNumber *first, RACSequence *rest) {
			int difference = first.intValue - [rest.head intValue];
			return @(difference);
		}];
		expect(result).to(equal(@2));
	});
});

qck_describe(@"-any", ^{
	__block RACSequence *sequence;
	qck_beforeEach(^{
		sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	});
	
	qck_it(@"should return true when at least one exists", ^{
		BOOL result = [sequence any:^ BOOL (NSNumber *value) {
			return value.integerValue > 0;
		}];
		expect(@(result)).to(beTruthy());
	});
	
	qck_it(@"should return false when no such thing exists", ^{
		BOOL result = [sequence any:^ BOOL (NSNumber *value) {
			return value.integerValue == 3;
		}];
		expect(@(result)).to(beFalsy());
	});
});

qck_describe(@"-all", ^{
	__block RACSequence *sequence;
	qck_beforeEach(^{
		sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	});
	
	qck_it(@"should return true when all values pass", ^{
		BOOL result = [sequence all:^ BOOL (NSNumber *value) {
			return value.integerValue >= 0;
		}];
		expect(@(result)).to(beTruthy());
	});
	
	qck_it(@"should return false when at least one value fails", ^{
		BOOL result = [sequence all:^ BOOL (NSNumber *value) {
			return value.integerValue < 2;
		}];
		expect(@(result)).to(beFalsy());
	});
});

qck_describe(@"-objectPassingTest:", ^{
	__block RACSequence *sequence;
	qck_beforeEach(^{
		sequence = [[[RACSequence return:@0] concat:[RACSequence return:@1]] concat:[RACSequence return:@2]];
	});
	
	qck_it(@"should return leftmost object that passes the test", ^{
		NSNumber *result = [sequence objectPassingTest:^ BOOL (NSNumber *value) {
			return value.intValue > 0;
		}];
		expect(result).to(equal(@1));
	});
	
	qck_it(@"should return nil if no objects pass the test", ^{
		NSNumber *result = [sequence objectPassingTest:^ BOOL (NSNumber *value) {
			return value.intValue < 0;
		}];
		expect(result).to(beNil());
	});
});

QuickSpecEnd
