//
//  RACSignalSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySignalExamples.h"
#import "RACSequenceExamples.h"
#import "RACStreamExamples.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBehaviorSubject.h"
#import "RACDisposable.h"
#import "RACEvent.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignal+Operations.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTestObject.h"
#import "RACTuple.h"
#import "RACUnit.h"

#define RACSignalTestError [NSError errorWithDomain:@"foo" code:100 userInfo:nil]

static NSString * const RACSignalMergeConcurrentCompletionExampleGroup = @"RACSignalMergeConcurrentCompletionExampleGroup";
static NSString * const RACSignalMaxConcurrent = @"RACSignalMaxConcurrent";
SharedExampleGroupsBegin(mergeConcurrentCompletionName);

sharedExamplesFor(RACSignalMergeConcurrentCompletionExampleGroup, ^(NSDictionary *data) {
	it(@"should complete only after the source and all its signals have completed", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];
		RACSubject *subject3 = [RACSubject subject];

		RACSubject *signalsSubject = [RACSubject subject];
		__block BOOL completed = NO;
		[[signalsSubject flatten:[data[RACSignalMaxConcurrent] unsignedIntegerValue]] subscribeCompleted:^{
			completed = YES;
		}];

		[signalsSubject sendNext:subject1];
		[subject1 sendCompleted];

		expect(completed).to.beFalsy();

		[signalsSubject sendNext:subject2];
		[signalsSubject sendNext:subject3];

		[signalsSubject sendCompleted];

		expect(completed).to.beFalsy();

		[subject2 sendCompleted];

		expect(completed).to.beFalsy();

		[subject3 sendCompleted];

		expect(completed).to.beTruthy();
	});
});

SharedExampleGroupsEnd

SpecBegin(RACSignal)

describe(@"RACStream", ^{
	id verifyValues = ^(RACSignal *signal, NSArray *expectedValues) {
		expect(signal).notTo.beNil();

		NSMutableArray *collectedValues = [NSMutableArray array];

		__block BOOL success = NO;
		__block NSError *error = nil;
		[signal subscribeNext:^(id value) {
			[collectedValues addObject:value];
		} error:^(NSError *receivedError) {
			error = receivedError;
		} completed:^{
			success = YES;
		}];

		expect(success).will.beTruthy();
		expect(error).to.beNil();
		expect(collectedValues).to.equal(expectedValues);
	};

	RACSignal *infiniteSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block volatile int32_t done = 0;

		[RACScheduler.mainThreadScheduler schedule:^{
			while (!done) {
				[subscriber sendNext:RACUnit.defaultUnit];
			}
		}];

		return [RACDisposable disposableWithBlock:^{
			OSAtomicIncrement32Barrier(&done);
		}];
	}];

	itShouldBehaveLike(RACStreamExamples, ^{
		return @{
			RACStreamExamplesClass: RACSignal.class,
			RACStreamExamplesVerifyValuesBlock: verifyValues,
			RACStreamExamplesInfiniteStream: infiniteSignal
		};
	});
});

describe(@"subscribing", ^{
	__block RACSignal *signal = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should get next values", ^{
		__block id nextValueReceived = nil;
		[signal subscribeNext:^(id x) {
			nextValueReceived = x;
		} error:^(NSError *error) {
			
		} completed:^{
			
		}];
		
		expect(nextValueReceived).to.equal(nextValueSent);
	});
	
	it(@"should get completed", ^{
		__block BOOL didGetCompleted = NO;
		[signal subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			
		} completed:^{
			didGetCompleted = YES;
		}];
		
		expect(didGetCompleted).to.beTruthy();
	});
	
	it(@"should not get an error", ^{
		__block BOOL didGetError = NO;
		[signal subscribeNext:^(id x) {
			
		} error:^(NSError *error) {
			didGetError = YES;
		} completed:^{
			
		}];
		
		expect(didGetError).to.beFalsy();
	});
	
	it(@"shouldn't get anything after dispose", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACDisposable *disposable = [subject subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];
		
		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];
		
		[disposable dispose];
		
		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});

	it(@"should have a current scheduler in didSubscribe block", ^{
		__block RACScheduler *currentScheduler;
		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			currentScheduler = RACScheduler.currentScheduler;
			[subscriber sendCompleted];
			return nil;
		}];

		[signal subscribeNext:^(id x) {}];
		expect(currentScheduler).notTo.beNil();

		currentScheduler = nil;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[signal subscribeNext:^(id x) {}];
		});
		expect(currentScheduler).willNot.beNil();
	});

	it(@"should support -takeUntil:", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];

		shouldBeGettingItems = YES;
		[subject sendNext:@"test 1"];
		[subject sendNext:@"test 2"];

		[cutOffSubject sendNext:[RACUnit defaultUnit]];

		shouldBeGettingItems = NO;
		[subject sendNext:@"test 3"];
	});
    
	it(@"should support -takeUntil: with completion as trigger", ^{
		__block BOOL shouldBeGettingItems = YES;
		RACSubject *subject = [RACSubject subject];
		RACSubject *cutOffSubject = [RACSubject subject];
		[[subject takeUntil:cutOffSubject] subscribeNext:^(id x) {
			expect(shouldBeGettingItems).to.beTruthy();
		}];
        
		[cutOffSubject sendCompleted];
        
		shouldBeGettingItems = NO;
		[subject sendNext:@"should not go through"];
	});
});

describe(@"disposal", ^{
	it(@"should dispose of the didSubscribe disposable", ^{
		__block BOOL innerDisposed = NO;
		RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}];
		}];

		expect(innerDisposed).to.beFalsy();

		RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
		expect(disposable).notTo.beNil();

		[disposable dispose];
		expect(innerDisposed).to.beTruthy();
	});

	it(@"should dispose of the didSubscribe disposable asynchronously", ^{
		__block BOOL innerDisposed = NO;
		RACSignal *signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}];
		}];

		[[RACScheduler scheduler] schedule:^{
			RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
			[disposable dispose];
		}];

		expect(innerDisposed).will.beTruthy();
	});
});

describe(@"querying", ^{
	__block RACSignal *signal = nil;
	id nextValueSent = @"1";
	
	beforeEach(^{
		signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:nextValueSent];
			[subscriber sendNext:@"other value"];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should support window", ^{
		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@"1"];
			[subscriber sendNext:@"2"];
			[subscriber sendNext:@"3"];
			[subscriber sendNext:@"4"];
			[subscriber sendNext:@"5"];
			[subscriber sendCompleted];
			return nil;
		}];
		
		RACBehaviorSubject *windowOpen = [RACBehaviorSubject behaviorSubjectWithDefaultValue:@""];
		
		RACSubject *closeSubject = [RACSubject subject];
		__block NSUInteger valuesReceived = 0;
		
		RACSignal *window = [signal windowWithStart:windowOpen close:^(RACSignal *start) {
			return closeSubject;
		}];
				
		[window subscribeNext:^(id x) {			
			[x subscribeNext:^(id x) {
				valuesReceived++;
				NSLog(@"got: %@", x);
				
				if(valuesReceived % 2 == 0) {
					[closeSubject sendNext:x];
					[windowOpen sendNext:@""];
				}
			} error:^(NSError *error) {
				
			} completed:^{
				
			}];
		} error:^(NSError *error) {
			
		} completed:^{
			NSLog(@"completed");
		}];
	});
	
	it(@"should return first 'next' value with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendCompleted];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@1);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return first default value with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendCompleted];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beTruthy();
		expect(error).to.beNil();
	});
	
	it(@"should return error with -firstOrDefault:success:error:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendError:RACSignalTestError];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"shouldn't crash when returning an error from a background scheduler", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[[RACScheduler scheduler] schedule:^{
				[subscriber sendError:RACSignalTestError];
			}];

			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(RACSignalTestError);
	});
});

describe(@"continuation", ^{
	it(@"should repeat after completion", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			if(numberOfSubscriptions > 2) {
				[subscriber sendError:RACSignalTestError];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[subscriber sendNext:@"1"];
			[subscriber sendCompleted];
			[subscriber sendError:RACSignalTestError];
			return nil;
		}];
		
		__block NSUInteger nextCount = 0;
		__block BOOL gotCompleted = NO;
		[[signal repeat] subscribeNext:^(id x) {
			nextCount++;
		} error:^(NSError *error) {
			
		} completed:^{
			gotCompleted = YES;
		}];
		
		expect(nextCount).will.beGreaterThan(1);
		expect(gotCompleted).to.beFalsy();
	});

	it(@"should stop repeating when disposed", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		__block RACDisposable *disposable = [[signal repeat] subscribeNext:^(id x) {
			[values addObject:x];
			[disposable dispose];
		} completed:^{
			completed = YES;
		}];

		expect(values).will.equal(@[ @1 ]);
		expect(completed).to.beFalsy();
	});

	it(@"should stop repeating when disposed by -take:", ^{
		RACSignal *signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];

		NSMutableArray *values = [NSMutableArray array];

		__block BOOL completed = NO;
		[[[signal repeat] take:1] subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		expect(values).will.equal(@[ @1 ]);
		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatestWith:", ^{
	__block RACSubject *subject1 = nil;
	__block RACSubject *subject2 = nil;
	__block RACSignal *combined = nil;
	
	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		combined = [RACSignal combineLatest:@[ subject1, subject2 ]];
	});
	
	it(@"should send next only once both signals send next", ^{
		__block RACTuple *tuple;
		
		[combined subscribeNext:^(id x) {
			tuple = x;
		}];
		
		expect(tuple).to.beNil();

		[subject1 sendNext:@"1"];
		expect(tuple).to.beNil();

		[subject2 sendNext:@"2"];
		expect(tuple).to.equal(RACTuplePack(@"1", @"2"));
	});
	
	it(@"should send nexts when either signal sends multiple times", ^{
		NSMutableArray *results = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[results addObject:x];
		}];
		
		[subject1 sendNext:@"1"];
		[subject2 sendNext:@"2"];
		
		[subject1 sendNext:@"3"];
		[subject2 sendNext:@"4"];
		
		expect(results[0]).to.equal(RACTuplePack(@"1", @"2"));
		expect(results[1]).to.equal(RACTuplePack(@"3", @"2"));
		expect(results[2]).to.equal(RACTuplePack(@"3", @"4"));
	});
	
	it(@"should complete when only both signals complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();
		
		[subject1 sendCompleted];
		expect(completed).to.beFalsy();

		[subject2 sendCompleted];
		expect(completed).to.beTruthy();
	});
	
	it(@"should error when either signal errors", ^{
		__block NSError *receivedError = nil;
		[combined subscribeError:^(NSError *error) {
			receivedError = error;
		}];
		
		[subject1 sendError:RACSignalTestError];
		expect(receivedError).to.equal(RACSignalTestError);
	});

	it(@"shouldn't create a retain cycle", ^{
		__block BOOL subjectDeallocd = NO;
		__block BOOL signalDeallocd = NO;

		@autoreleasepool {
			RACSubject *subject __attribute__((objc_precise_lifetime)) = [RACSubject subject];
			[subject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				subjectDeallocd = YES;
			}]];
			
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal combineLatest:@[ subject ]];
			[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocd = YES;
			}]];

			[signal subscribeCompleted:^{}];
			[subject sendCompleted];
		}

		expect(subjectDeallocd).will.beTruthy();
		expect(signalDeallocd).will.beTruthy();
	});

	it(@"should combine the same signal", ^{
		RACSignal *combined = [subject1 combineLatestWith:subject1];

		__block RACTuple *tuple;
		[combined subscribeNext:^(id x) {
			tuple = x;
		}];
		
		[subject1 sendNext:@"foo"];
		expect(tuple).to.equal(RACTuplePack(@"foo", @"foo"));
		
		[subject1 sendNext:@"bar"];
		expect(tuple).to.equal(RACTuplePack(@"bar", @"bar"));
	});
    
	it(@"should combine the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@(++counter)];
			[subscriber sendCompleted];
			return nil;
		}];

		RACSignal *combined = [sideEffectingSignal combineLatestWith:sideEffectingSignal];
		expect(counter).to.equal(0);

		NSMutableArray *receivedValues = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(2);

		NSArray *expected = @[ RACTuplePack(@1, @2) ];
		expect(receivedValues).to.equal(expected);
	});
});

describe(@"+combineLatest:", ^{
	it(@"should return tuples even when only combining one signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block RACTuple *tuple;
		[[RACSignal combineLatest:@[ subject ]] subscribeNext:^(id x) {
			tuple = x;
		}];

		[subject sendNext:@"foo"];
		expect(tuple).to.equal(RACTuplePack(@"foo"));
	});

	it(@"should complete immediately when not given any signals", ^{
		RACSignal *signal = [RACSignal combineLatest:@[]];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});

	it(@"should only complete after all its signals complete", ^{
		RACSubject *subject1 = [RACSubject subject];
		RACSubject *subject2 = [RACSubject subject];
		RACSubject *subject3 = [RACSubject subject];
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ]];

		__block BOOL completed = NO;
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();

		[subject1 sendCompleted];
		expect(completed).to.beFalsy();

		[subject2 sendCompleted];
		expect(completed).to.beFalsy();

		[subject3 sendCompleted];
		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatest:reduce:", ^{
	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;

	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		subject3 = [RACSubject subject];
	});

	it(@"should send nils for nil values", ^{
		__block id receivedVal1;
		__block id receivedVal2;
		__block id receivedVal3;

		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ] reduce:^(id val1, id val2, id val3) {
			receivedVal1 = val1;
			receivedVal2 = val2;
			receivedVal3 = val3;
			return nil;
		}];

		__block BOOL gotValue = NO;
		[combined subscribeNext:^(id x) {
			gotValue = YES;
		}];

		[subject1 sendNext:nil];
		[subject2 sendNext:nil];
		[subject3 sendNext:nil];

		expect(gotValue).to.beTruthy();
		expect(receivedVal1).to.beNil();
		expect(receivedVal2).to.beNil();
		expect(receivedVal3).to.beNil();
	});

	it(@"should send the return result of the reduce block", ^{
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject3 ] reduce:^(NSString *string1, NSString *string2, NSString *string3) {
			return [NSString stringWithFormat:@"%@: %@%@", string1, string2, string3];
		}];

		__block id received;
		[combined subscribeNext:^(id x) {
			received = x;
		}];

		[subject1 sendNext:@"hello"];
		[subject2 sendNext:@"world"];
		[subject3 sendNext:@"!!1"];

		expect(received).to.equal(@"hello: world!!1");
	});
	
	it(@"should handle multiples of the same signals", ^{
		RACSignal *combined = [RACSignal combineLatest:@[ subject1, subject2, subject1, subject3 ] reduce:^(NSString *string1, NSString *string2, NSString *string3, NSString *string4) {
			return [NSString stringWithFormat:@"%@ : %@ = %@ : %@", string1, string2, string3, string4];
		}];
		
		NSMutableArray *receivedValues = NSMutableArray.array;
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		[subject1 sendNext:@"apples"];
		expect(receivedValues.lastObject).to.beNil();
		
		[subject2 sendNext:@"oranges"];
		expect(receivedValues.lastObject).to.beNil();

		[subject3 sendNext:@"cattle"];
		expect(receivedValues.lastObject).to.equal(@"apples : oranges = apples : cattle");
		
		[subject1 sendNext:@"horses"];
		expect(receivedValues.lastObject).to.equal(@"horses : oranges = horses : cattle");
	});
    
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@(++counter)];
			[subscriber sendCompleted];
			return nil;
		}];

		RACSignal *combined = [RACSignal combineLatest:@[ sideEffectingSignal, sideEffectingSignal, sideEffectingSignal ] reduce:^(id x, id y, id z) {
			return [NSString stringWithFormat:@"%@%@%@", x, y, z];
		}];

		NSMutableArray *receivedValues = [NSMutableArray array];
		expect(counter).to.equal(0);
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(3);
		expect(receivedValues).to.equal(@[ @"123" ]);
	});
});

describe(@"distinctUntilChanged", ^{
	it(@"should only send values that are distinct from the previous value", ^{
		RACSignal *sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@2];
			[subscriber sendNext:@1];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ @1, @2, @1 ];
		expect(values).to.equal(expected);
	});

	it(@"shouldn't consider nils to always be distinct", ^{
		RACSignal *sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ @1, [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});

	it(@"should consider initial nil to be distinct", ^{
		RACSignal *sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:nil];
			[subscriber sendNext:nil];
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}] distinctUntilChanged];
		
		NSArray *values = sub.toArray;
		NSArray *expected = @[ [NSNull null], @1 ];
		expect(values).to.equal(expected);
	});
});

describe(@"RACAbleWithStart", ^{
	__block RACTestObject *testObject;

	beforeEach(^{
		testObject = [[RACTestObject alloc] init];
	});

	it(@"should work with object properties", ^{
		NSArray *expected = @[ @"hello", @"world" ];
		testObject.objectValue = expected[0];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACAbleWithStart(testObject, objectValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.objectValue = expected[1];

		expect(valuesReceived).to.equal(expected);
	});

	it(@"should work with non-object properties", ^{
		NSArray *expected = @[ @42, @43 ];
		testObject.integerValue = [expected[0] integerValue];

		NSMutableArray *valuesReceived = [NSMutableArray array];
		[RACAbleWithStart(testObject, integerValue) subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		testObject.integerValue = [expected[1] integerValue];

		expect(valuesReceived).to.equal(expected);
	});
});

describe(@"-toProperty:onObject:", ^{
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, RACSignal *signal) {
		[signal toProperty:keyPath onObject:testObject];
	};

	itShouldBehaveLike(RACPropertySignalExamples, ^{
		return @{ RACPropertySignalExamplesSetupBlock: setupBlock };
	});

	it(@"shouldn't send values to dealloc'd objects", ^{
		RACSubject *subject = [RACSubject subject];
		@autoreleasepool {
			RACTestObject *testObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[subject toProperty:@keypath(testObject.objectValue) onObject:testObject];
			expect(testObject.objectValue).to.beNil();

			[subject sendNext:@1];
			expect(testObject.objectValue).to.equal(@1);

			[subject sendNext:@2];
			expect(testObject.objectValue).to.equal(@2);
		}

		// This shouldn't do anything.
		[subject sendNext:@3];
	});
});

describe(@"memory management", ^{
	it(@"should dealloc signals if the signal does nothing", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
				return nil;
			}];

			[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
		}

		expect(deallocd).will.beTruthy();
	});

	it(@"should retain signals for a single run loop iteration", ^{
		__block BOOL deallocd = NO;

		@autoreleasepool {
			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
				return nil;
			}];

			[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
		}

		expect(deallocd).to.beFalsy();
		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc signals if the signal immediately completes", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			__block BOOL done = NO;

			RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
				[subscriber sendCompleted];
				return nil;
			}];

			[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];

			[signal subscribeCompleted:^{
				done = YES;
			}];

			expect(done).will.beTruthy();
		}
		
		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc a replay subject if it completes immediately", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACReplaySubject *subject __attribute__((objc_precise_lifetime)) = [RACReplaySubject subject];
			[subject sendCompleted];

			[subject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];

			[subject subscribeCompleted:^{
				completed = YES;
			}];
		}

		expect(completed).will.beTruthy();

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc if the signal was created on a background queue", ^{
		__block BOOL completed = NO;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[[RACScheduler scheduler] schedule:^{
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
					[subscriber sendCompleted];
					return nil;
				}];

				[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				[signal subscribeCompleted:^{
					completed = YES;
				}];
			}];
		}

		expect(completed).will.beTruthy();

		expect(deallocd).will.beTruthy();
	});

	it(@"should dealloc if the signal was created on a background queue, never gets any subscribers, and the background queue gets delayed", ^{
		__block BOOL deallocd = NO;
		@autoreleasepool {
			[[RACScheduler scheduler] schedule:^{
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
					return nil;
				}];

				[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				[NSThread sleepForTimeInterval:1];

				expect(deallocd).to.beFalsy();
			}];
		}

		// The default test timeout is 1s so we'd race to see if the queue delay
		// or default timeout happens first. To avoid that, just bump the
		// timeout slightly for this test.
		NSTimeInterval originalTestTimeout = Expecta.asynchronousTestTimeout;
		Expecta.asynchronousTestTimeout = 1.1f;
		expect(deallocd).will.beTruthy();
		Expecta.asynchronousTestTimeout = originalTestTimeout;
	});

	it(@"should retain signals when subscribing", ^{
		__block BOOL deallocd = NO;

		RACDisposable *disposable;

		@autoreleasepool {
			@autoreleasepool {
				RACSignal *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
					return nil;
				}];

				[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
					deallocd = YES;
				}]];

				disposable = [signal subscribeCompleted:^{}];
			}

			// Spin the run loop to account for RAC magic that retains the
			// signal for a single iteration.
			[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
		}

		expect(deallocd).to.beFalsy();

		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});

	it(@"should retain intermediate signals when subscribing", ^{
		RACSubject *subject = [RACSubject subject];
		expect(subject).notTo.beNil();

		__block BOOL gotNext = NO;
		__block BOOL completed = NO;

		RACDisposable *disposable;

		@autoreleasepool {
			@autoreleasepool {
				RACSignal *intermediateSignal = [subject doNext:^(id _) {
					gotNext = YES;
				}];

				expect(intermediateSignal).notTo.beNil();

				disposable = [intermediateSignal subscribeCompleted:^{
					completed = YES;
				}];
			}

			// Spin the run loop to account for RAC magic that retains the
			// signal for a single iteration.
			[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate date]];
		}

		[subject sendNext:@5];
		expect(gotNext).to.beTruthy();

		[subject sendCompleted];
		expect(completed).to.beTruthy();
		
		[disposable dispose];
	});
});

describe(@"+merge:", ^{
	__block RACSubject *sub1;
	__block RACSubject *sub2;
	__block RACSignal *merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [RACSignal merge:@[ sub1, sub2 ].objectEnumerator];
	});

	it(@"should send all values from both signals", ^{
		NSMutableArray *values = [NSMutableArray array];
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub1 sendNext:@4];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send an error if one occurs", ^{
		__block NSError *errorReceived;
		[merged subscribeError:^(NSError *error) {
			errorReceived = error;
		}];

		[sub1 sendError:RACSignalTestError];
		expect(errorReceived).to.equal(RACSignalTestError);
	});

	it(@"should complete only after both signals complete", ^{
		NSMutableArray *values = [NSMutableArray array];
		__block BOOL completed = NO;
		[merged subscribeNext:^(id x) {
			[values addObject:x];
		} completed:^{
			completed = YES;
		}];

		[sub1 sendNext:@1];
		[sub2 sendNext:@2];
		[sub2 sendNext:@3];
		[sub2 sendCompleted];
		expect(completed).to.beFalsy();

		[sub1 sendNext:@4];
		[sub1 sendCompleted];
		expect(completed).to.beTruthy();

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete immediately when not given any signals", ^{
		RACSignal *signal = [RACSignal merge:@[].objectEnumerator];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});
});

describe(@"-flatten:", ^{
	__block BOOL subscribedTo1 = NO;
	__block BOOL subscribedTo2 = NO;
	__block BOOL subscribedTo3 = NO;
	__block RACSignal *sub1;
	__block RACSignal *sub2;
	__block RACSignal *sub3;
	__block RACSubject *subject1;
	__block RACSubject *subject2;
	__block RACSubject *subject3;
	__block RACSubject *signalsSubject;
	__block NSMutableArray *values;
	
	beforeEach(^{
		subscribedTo1 = NO;
		subject1 = [RACSubject subject];
		sub1 = [RACSignal defer:^{
			subscribedTo1 = YES;
			return subject1;
		}];

		subscribedTo2 = NO;
		subject2 = [RACSubject subject];
		sub2 = [RACSignal defer:^{
			subscribedTo2 = YES;
			return subject2;
		}];

		subscribedTo3 = NO;
		subject3 = [RACSubject subject];
		sub3 = [RACSignal defer:^{
			subscribedTo3 = YES;
			return subject3;
		}];

		signalsSubject = [RACSubject subject];

		values = [NSMutableArray array];
	});

	describe(@"when its max is 0", ^{
		it(@"should merge all the signals concurrently", ^{
			[[signalsSubject flatten:0] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribedTo1).to.beFalsy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[signalsSubject sendNext:sub1];
			[signalsSubject sendNext:sub2];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendNext:@1];

			[signalsSubject sendNext:sub3];
			
			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beTruthy();

			[subject1 sendCompleted];

			[subject2 sendNext:@2];
			[subject2 sendCompleted];

			[subject3 sendNext:@3];
			[subject3 sendCompleted];

			NSArray *expected = @[ @1, @2, @3 ];
			expect(values).to.equal(expected);
		});

		itShouldBehaveLike(RACSignalMergeConcurrentCompletionExampleGroup, @{ RACSignalMaxConcurrent: @0 });
	});

	describe(@"when its max is > 0", ^{
		it(@"should merge only the given number at a time", ^{
			[[signalsSubject flatten:1] subscribeNext:^(id x) {
				[values addObject:x];
			}];

			expect(subscribedTo1).to.beFalsy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[signalsSubject sendNext:sub1];
			[signalsSubject sendNext:sub2];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendNext:@1];

			[signalsSubject sendNext:sub3];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[signalsSubject sendCompleted];

			expect(subscribedTo1).to.beTruthy();
			expect(subscribedTo2).to.beFalsy();
			expect(subscribedTo3).to.beFalsy();

			[subject1 sendCompleted];

			expect(subscribedTo2).to.beTruthy();
			expect(subscribedTo3).to.beFalsy();

			[subject2 sendNext:@2];
			[subject2 sendCompleted];

			expect(subscribedTo3).to.beTruthy();

			[subject3 sendNext:@3];
			[subject3 sendCompleted];

			NSArray *expected = @[ @1, @2, @3 ];
			expect(values).to.equal(expected);
		});

		itShouldBehaveLike(RACSignalMergeConcurrentCompletionExampleGroup, @{ RACSignalMaxConcurrent: @1 });
	});

	it(@"shouldn't create a retain cycle", ^{
		__block BOOL subjectDeallocd = NO;
		__block BOOL signalDeallocd = NO;
		@autoreleasepool {
			RACSubject *subject __attribute__((objc_precise_lifetime)) = [RACSubject subject];
			[subject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				subjectDeallocd = YES;
			}]];

			RACSignal *signal __attribute__((objc_precise_lifetime)) = [subject flatten];
			[signal rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				signalDeallocd = YES;
			}]];

			[signal subscribeCompleted:^{}];

			[subject sendCompleted];
		}

		expect(subjectDeallocd).will.beTruthy();
		expect(signalDeallocd).will.beTruthy();
	});
});

describe(@"-switchToLatest", ^{
	__block RACSubject *subject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		subject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		[[subject switchToLatest] subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should send values from the most recent signal", ^{
		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			return nil;
		}]];

		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@3];
			[subscriber sendNext:@4];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should send errors from the most recent signal", ^{
		[subject sendNext:[RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return nil;
		}]];

		expect(lastError).notTo.beNil();
	});

	it(@"should send completed only when the switching signal completes", ^{
		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendCompleted];
			return nil;
		}]];

		expect(completed).to.beFalsy();

		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should accept nil signals", ^{
		[subject sendNext:nil];
		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2 ];
		expect(values).to.equal(expected);
	});
});

describe(@"+if:then:else", ^{
	__block RACSubject *boolSubject;
	__block RACSubject *trueSubject;
	__block RACSubject *falseSubject;

	__block NSMutableArray *values;
	__block NSError *lastError = nil;
	__block BOOL completed = NO;

	beforeEach(^{
		boolSubject = [RACSubject subject];
		trueSubject = [RACSubject subject];
		falseSubject = [RACSubject subject];

		values = [NSMutableArray array];
		lastError = nil;
		completed = NO;

		[[RACSignal if:boolSubject then:trueSubject else:falseSubject] subscribeNext:^(id x) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			[values addObject:x];
		} error:^(NSError *error) {
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			lastError = error;
		} completed:^{
			expect(lastError).to.beNil();
			expect(completed).to.beFalsy();

			completed = YES;
		}];
	});

	it(@"should not send any values before a boolean is sent", ^{
		[trueSubject sendNext:RACUnit.defaultUnit];
		[falseSubject sendNext:RACUnit.defaultUnit];

		expect(values).to.equal(@[]);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();
	});

	it(@"should send events based on the latest boolean", ^{
		[boolSubject sendNext:@YES];

		[trueSubject sendNext:@"foo"];
		[falseSubject sendNext:@"buzz"];
		[trueSubject sendNext:@"bar"];

		NSArray *expected = @[ @"foo", @"bar" ];
		expect(values).to.equal(expected);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[boolSubject sendNext:@NO];

		[trueSubject sendNext:@"baz"];
		[falseSubject sendNext:@"buzz"];
		[trueSubject sendNext:@"barfoo"];

		expected = @[ @"foo", @"bar", @"buzz" ];
		expect(values).to.equal(expected);
		expect(lastError).to.beNil();
		expect(completed).to.beFalsy();

		[trueSubject sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).to.beNil();

		[falseSubject sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		expect(lastError).notTo.beNil();
	});

	it(@"should send completed when the BOOL signal completes", ^{
		[boolSubject sendNext:@YES];
		[trueSubject sendNext:@"foo"];
		[boolSubject sendCompleted];

		expect(values).to.equal(@[ @"foo" ]);
		expect(completed).to.beTruthy();
	});
});

describe(@"+interval: and +interval:withLeeway:", ^{
	static const NSTimeInterval interval = 0.1;
	static const NSTimeInterval leeway = 0.2;
	static const NSTimeInterval marginOfError = 0.01;
	__block RACSignal *timer = nil;
	
	__block void (^testTimer)(RACSignal *, RACScheduler *, NSNumber *, NSNumber *) = nil;
	
	before(^{
		testTimer = [^(RACSignal *timer, RACScheduler *scheduler, NSNumber *minInterval, NSNumber *leeway) {
			__block NSUInteger nextsReceived = 0;
			[scheduler schedule:^{
				RACSignal *finalSignal = [[timer take:3] deliverOn:RACScheduler.mainThreadScheduler];

				NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate;
				[finalSignal subscribeNext:^(NSDate *date) {
					++nextsReceived;

					NSTimeInterval currentTime = date.timeIntervalSinceReferenceDate;

					// Uniformly distribute the expected interval for all
					// received values. We do this instead of saving a timestamp
					// because a delayed interval may cause the _next_ value to
					// send sooner than the interval.
					NSTimeInterval expectedMinInterval = minInterval.doubleValue * nextsReceived;
					NSTimeInterval expectedMaxInterval = expectedMinInterval + leeway.doubleValue;

					expect(currentTime - startTime).beGreaterThanOrEqualTo(expectedMinInterval - marginOfError);
					expect(currentTime - startTime).beLessThanOrEqualTo(expectedMaxInterval + marginOfError);
				}];
			}];
			
			expect(nextsReceived).will.equal(3);
		} copy];
	});
	
	describe(@"+interval", ^{
		before(^{
			timer = [RACSignal interval:interval];
		});
		
		it(@"should fire repeatedly at every interval", ^{
			testTimer(timer, RACScheduler.immediateScheduler, @(interval), @0);
		});
		
		it(@"should work on the main thread scheduler", ^{
			testTimer(timer, RACScheduler.mainThreadScheduler, @(interval), @0);
		});
		
		it(@"should work on a background scheduler", ^{
			testTimer(timer, [RACScheduler scheduler], @(interval), @0);
		});
	});
	
	describe(@"+interval:withLeeway:", ^{
		before(^{
			timer = [RACSignal interval:interval withLeeway:leeway];
		});
		
		it(@"should fire repeatedly at every interval", ^{
			testTimer(timer, RACScheduler.immediateScheduler, @(interval), @(leeway));
		});
		
		it(@"should work on the main thread scheduler", ^{
			testTimer(timer, RACScheduler.mainThreadScheduler, @(interval), @(leeway));
		});
		
		it(@"should work on a background scheduler", ^{
			testTimer(timer, [RACScheduler scheduler], @(interval), @(leeway));
		});
	});
});

describe(@"-timeout:", ^{
	__block RACSubject *subject;

	beforeEach(^{
		subject = [RACSubject subject];
	});

	it(@"should time out", ^{
		__block NSError *receivedError = nil;
		[[subject timeout:0.0001] subscribeError:^(NSError *e) {
			receivedError = e;
		}];

		expect(receivedError).willNot.beNil();
		expect(receivedError.domain).to.equal(RACSignalErrorDomain);
		expect(receivedError.code).to.equal(RACSignalErrorTimedOut);
	});

	it(@"should pass through events while not timed out", ^{
		__block id next = nil;
		__block BOOL completed = NO;
		[[subject timeout:1] subscribeNext:^(id x) {
			next = x;
		} completed:^{
			completed = YES;
		}];

		[subject sendNext:RACUnit.defaultUnit];
		expect(next).to.equal(RACUnit.defaultUnit);

		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should not time out after disposal", ^{
		__block NSError *receivedError = nil;
		RACDisposable *disposable = [[subject timeout:0.01] subscribeError:^(NSError *e) {
			receivedError = e;
		}];

		__block BOOL done = NO;
		[[[RACSignal interval:0.1] take:1] subscribeNext:^(id _) {
			done = YES;
		}];

		[disposable dispose];

		expect(done).will.beTruthy();
		expect(receivedError).to.beNil();
	});
});

describe(@"-delay:", ^{
	__block RACSubject *subject;
	__block RACSignal *delayedSignal;

	beforeEach(^{
		subject = [RACSubject subject];
		delayedSignal = [subject delay:0];
	});

	it(@"should delay nexts", ^{
		__block id next = nil;
		[delayedSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];
		expect(next).to.beNil();
		expect(next).will.equal(@"foo");
	});

	it(@"should delay completed", ^{
		__block BOOL completed = NO;
		[delayedSignal subscribeCompleted:^{
			completed = YES;
		}];

		[subject sendCompleted];
		expect(completed).to.beFalsy();
		expect(completed).will.beTruthy();
	});

	it(@"should not delay errors", ^{
		__block NSError *error = nil;
		[delayedSignal subscribeError:^(NSError *e) {
			error = e;
		}];

		[subject sendError:RACSignalTestError];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should cancel delayed events when disposed", ^{
		__block id next = nil;
		RACDisposable *disposable = [delayedSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];

		__block BOOL done = NO;
		[RACScheduler.mainThreadScheduler after:dispatch_time(DISPATCH_TIME_NOW, 1) schedule:^{
			done = YES;
		}];

		[disposable dispose];

		expect(done).will.beTruthy();
		expect(next).to.beNil();
	});
});

describe(@"-throttle:", ^{
	__block RACSubject *subject;
	__block RACSignal *throttledSignal;

	beforeEach(^{
		subject = [RACSubject subject];
		throttledSignal = [subject throttle:0];
	});

	it(@"should throttle nexts", ^{
		NSMutableArray *valuesReceived = [NSMutableArray array];
		[throttledSignal subscribeNext:^(id x) {
			[valuesReceived addObject:x];
		}];

		[subject sendNext:@"foo"];
		[subject sendNext:@"bar"];
		expect(valuesReceived).to.equal(@[]);

		NSArray *expected = @[ @"bar" ];
		expect(valuesReceived).will.equal(expected);

		[subject sendNext:@"buzz"];
		expect(valuesReceived).to.equal(expected);

		expected = @[ @"bar", @"buzz" ];
		expect(valuesReceived).will.equal(expected);
	});

	it(@"should forward completed immediately", ^{
		__block BOOL completed = NO;
		[throttledSignal subscribeCompleted:^{
			completed = YES;
		}];

		[subject sendCompleted];
		expect(completed).to.beTruthy();
	});

	it(@"should forward errors immediately", ^{
		__block NSError *error = nil;
		[throttledSignal subscribeError:^(NSError *e) {
			error = e;
		}];

		[subject sendError:RACSignalTestError];
		expect(error).to.equal(RACSignalTestError);
	});

	it(@"should cancel future nexts when disposed", ^{
		__block id next = nil;
		RACDisposable *disposable = [throttledSignal subscribeNext:^(id x) {
			next = x;
		}];

		[subject sendNext:@"foo"];

		__block BOOL done = NO;
		[RACScheduler.mainThreadScheduler after:dispatch_time(DISPATCH_TIME_NOW, 1) schedule:^{
			done = YES;
		}];

		[disposable dispose];

		expect(done).will.beTruthy();
		expect(next).to.beNil();
	});
});

describe(@"-sequenceNext:", ^{
	it(@"should continue onto returned signal", ^{
		RACSubject *subject = [RACSubject subject];

		__block id value = nil;
		[[subject sequenceNext:^{
			return [RACSignal return:@2];
		}] subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendNext:@1];

		// The value shouldn't change until the first signal completes.
		expect(value).to.beNil();

		[subject sendCompleted];

		expect(value).to.equal(@2);
	});

	it(@"should sequence even if no next value is sent", ^{
		RACSubject *subject = [RACSubject subject];

		__block id value = nil;
		[[subject sequenceNext:^{
			return [RACSignal return:RACUnit.defaultUnit];
		}] subscribeNext:^(id x) {
			value = x;
		}];

		[subject sendCompleted];

		expect(value).to.equal(RACUnit.defaultUnit);
	});
});

describe(@"-sequence", ^{
	RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:@1];
		[subscriber sendNext:@2];
		[subscriber sendNext:@3];
		[subscriber sendNext:@4];
		[subscriber sendCompleted];
		return nil;
	}];

	itShouldBehaveLike(RACSequenceExamples, ^{
		return @{
			RACSequenceExampleSequence: signal.sequence,
			RACSequenceExampleExpectedValues: @[ @1, @2, @3, @4 ]
		};
	});
});

it(@"should complete take: even if the original signal doesn't", ^{
	RACSignal *sendOne = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:RACUnit.defaultUnit];
		return nil;
	}];

	__block id value = nil;
	__block BOOL completed = NO;
	[[sendOne take:1] subscribeNext:^(id received) {
		value = received;
	} completed:^{
		completed = YES;
	}];

	expect(value).to.equal(RACUnit.defaultUnit);
	expect(completed).to.beTruthy();
});

describe(@"+zip:", ^{
	__block RACSubject *subject1 = nil;
	__block RACSubject *subject2 = nil;
	__block BOOL hasSentError = NO;
	__block BOOL hasSentCompleted = NO;
	__block RACDisposable *disposable = nil;
	__block void (^send2NextAndErrorTo1)(void) = nil;
	__block void (^send3NextAndErrorTo1)(void) = nil;
	__block void (^send2NextAndCompletedTo2)(void) = nil;
	__block void (^send3NextAndCompletedTo2)(void) = nil;
	
	before(^{
		send2NextAndErrorTo1 = [^{
			[subject1 sendNext:@1];
			[subject1 sendNext:@2];
			[subject1 sendError:RACSignalTestError];
		} copy];
		send3NextAndErrorTo1 = [^{
			[subject1 sendNext:@1];
			[subject1 sendNext:@2];
			[subject1 sendNext:@3];
			[subject1 sendError:RACSignalTestError];
		} copy];
		send2NextAndCompletedTo2 = [^{
			[subject2 sendNext:@1];
			[subject2 sendNext:@2];
			[subject2 sendCompleted];
		} copy];
		send3NextAndCompletedTo2 = [^{
			[subject2 sendNext:@1];
			[subject2 sendNext:@2];
			[subject2 sendNext:@3];
			[subject2 sendCompleted];
		} copy];
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
		hasSentError = NO;
		hasSentCompleted = NO;
		disposable = [[RACSignal zip:@[ subject1, subject2 ]] subscribeError:^(NSError *error) {
			hasSentError = YES;
		} completed:^{
			hasSentCompleted = YES;
		}];
	});
	
	after(^{
		[disposable dispose];
	});
	
	it(@"should complete as soon as no new zipped values are possible", ^{
		[subject1 sendNext:@1];
		[subject2 sendNext:@1];
		expect(hasSentCompleted).to.beFalsy();
		
		[subject1 sendNext:@2];
		[subject1 sendCompleted];
		expect(hasSentCompleted).to.beFalsy();
		
		[subject2 sendNext:@2];
		expect(hasSentCompleted).to.beTruthy();
	});
	
	it(@"outcome should not be dependent on order of signals", ^{
		[subject2 sendCompleted];
		expect(hasSentCompleted).to.beTruthy();
	});
    
	it(@"should forward errors sent earlier than (time-wise) and before (position-wise) a complete", ^{
		send2NextAndErrorTo1();
		send3NextAndCompletedTo2();
		expect(hasSentError).to.beTruthy();
		expect(hasSentCompleted).to.beFalsy();
	});
	
	it(@"should forward errors sent earlier than (time-wise) and after (position-wise) a complete", ^{
		send3NextAndErrorTo1();
		send2NextAndCompletedTo2();
		expect(hasSentError).to.beTruthy();
		expect(hasSentCompleted).to.beFalsy();
	});
	
	it(@"should forward errors sent later than (time-wise) and before (position-wise) a complete", ^{
		send3NextAndCompletedTo2();
		send2NextAndErrorTo1();
		expect(hasSentError).to.beTruthy();
		expect(hasSentCompleted).to.beFalsy();
	});
	
	it(@"should ignore errors sent later than (time-wise) and after (position-wise) a complete", ^{
		send2NextAndCompletedTo2();
		send3NextAndErrorTo1();
		expect(hasSentError).to.beFalsy();
		expect(hasSentCompleted).to.beTruthy();
	});
	
	it(@"should handle signals sending values unevenly", ^{
		__block NSError *receivedError = nil;
		__block BOOL hasCompleted = NO;
		
		RACSubject *a = [RACSubject subject];
		RACSubject *b = [RACSubject subject];
		RACSubject *c = [RACSubject subject];
		
		NSMutableArray *receivedValues = NSMutableArray.array;
		NSArray *expectedValues = nil;
		
		[[RACSignal zip:@[ a, b, c ] reduce:^(NSNumber *a, NSNumber *b, NSNumber *c) {
			return [NSString stringWithFormat:@"%@%@%@", a, b, c];
		}] subscribeNext:^(id x) {
			[receivedValues addObject:x];
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			hasCompleted = YES;
		}];
		
		[a sendNext:@1];
		[a sendNext:@2];
		[a sendNext:@3];
		
		[b sendNext:@1];
		
		[c sendNext:@1];
		[c sendNext:@2];
		
		// a: [===......]
		// b: [=........]
		// c: [==.......]
		
		expectedValues = @[ @"111" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.beNil();
		expect(hasCompleted).to.beFalsy();
		
		[b sendNext:@2];
		[b sendNext:@3];
		[b sendNext:@4];
		[b sendCompleted];
		
		// a: [===......]
		// b: [====C....]
		// c: [==.......]
		
		expectedValues = @[ @"111", @"222" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.beNil();
		expect(hasCompleted).to.beFalsy();
		
		[c sendNext:@3];
		[c sendNext:@4];
		[c sendNext:@5];
		[c sendError:RACSignalTestError];
		
		// a: [===......]
		// b: [====C....]
		// c: [=====E...]
		
		expectedValues = @[ @"111", @"222", @"333" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.equal(RACSignalTestError);
		expect(hasCompleted).to.beFalsy();
		
		[a sendNext:@4];
		[a sendNext:@5];
		[a sendNext:@6];
		[a sendNext:@7];
		
		// a: [=======..]
		// b: [====C....]
		// c: [=====E...]
		
		expectedValues = @[ @"111", @"222", @"333" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.equal(RACSignalTestError);
		expect(hasCompleted).to.beFalsy();
	});
	
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		RACSignal *sideEffectingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			++counter;
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];
		RACSignal *combined = [RACSignal zip:@[ sideEffectingSignal, sideEffectingSignal ] reduce:^ NSString * (id x, id y) {
			return [NSString stringWithFormat:@"%@%@", x, y];
		}];
		NSMutableArray *receivedValues = NSMutableArray.array;
		
		expect(counter).to.equal(0);
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		expect(counter).to.equal(2);
		expect(receivedValues).to.equal(@[ @"11" ]);
	});
});

describe(@"-sample:", ^{
	it(@"should send the latest value when the sampler signal fires", ^{
		RACSubject *subject = [RACSubject subject];
		RACSubject *sampleSubject = [RACSubject subject];
		RACSignal *sampled = [subject sample:sampleSubject];
		NSMutableArray *values = [NSMutableArray array];
		[sampled subscribeNext:^(id x) {
			[values addObject:x];
		}];
		
		[subject sendNext:@1];
		[subject sendNext:@2];
		expect(values).to.equal(@[]);

		[sampleSubject sendNext:RACUnit.defaultUnit];
		NSArray *expected = @[ @2 ];
		expect(values).to.equal(expected);

		[subject sendNext:@3];
		expect(values).to.equal(expected);

		[sampleSubject sendNext:RACUnit.defaultUnit];
		expected = @[ @2, @3 ];
		expect(values).to.equal(expected);

		[sampleSubject sendNext:RACUnit.defaultUnit];
		expected = @[ @2, @3, @3 ];
		expect(values).to.equal(expected);
	});
});

describe(@"-collect", ^{
	it(@"should send a single array when the original signal completes", ^{
		RACSubject *subject = [RACSubject subject];
		RACSignal *collected = [subject collect];

		NSArray *expected = @[ @1, @2, @3 ];
		__block id value = nil;
		__block BOOL hasCompleted = NO;

		[collected subscribeNext:^(id x) {
			value = x;
		} completed:^{
			hasCompleted = YES;
		}];

		[subject sendNext:@1];
		[subject sendNext:@2];
		[subject sendNext:@3];
		expect(value).to.beNil();

		[subject sendCompleted];
		expect(value).to.equal(expected);
		expect(hasCompleted).to.beTruthy();
	});
});

describe(@"-bufferWithTime:", ^{
	it(@"should buffer nexts and restart buffering if new next arrives", ^{
		RACSubject *input = [RACSubject subject];
		
		RACSignal *bufferedInput = [input bufferWithTime:0.1];
		
		__block NSArray *received = nil;
		
		[bufferedInput subscribeNext:^(RACTuple *x) {
			received = [x allObjects];
		}];
		
		[input sendNext:@1];
		[input sendNext:@2];
		
		expect(received).will.equal((@[ @1, @2 ]));
		
		[input sendNext:@3];
		// NSNull should not be converted
		[input sendNext:NSNull.null];
		
		expect(received).will.equal((@[ @3, NSNull.null ]));
	});
	
});


describe(@"-buffer:", ^{
	it(@"should buffer nexts and restart buffering if new next arrives", ^{
		RACSubject *input = [RACSubject subject];
		
		RACSignal *bufferedInput = [input buffer:2];

		__block NSArray *received = nil;
		
		[bufferedInput subscribeNext:^(RACTuple *x) {
			received = [x allObjects];
		}];

		[input sendNext:@1];
		[input sendNext:@2];
		
		expect(received).to.equal((@[ @1, @2 ]));
		
		[input sendNext:@3];
		[input sendNext:@4];
		[input sendNext:@5];
		
		expect(received).to.equal((@[ @3, @4 ]));

		// NSNull should not be converted
		[input sendNext:NSNull.null];
		
		expect(received).to.equal((@[ @5, NSNull.null ]));
	});
});

describe(@"-concat", ^{
	__block RACSubject *subject;

	__block RACSignal *oneSignal;
	__block RACSignal *twoSignal;
	__block RACSignal *threeSignal;

	__block RACSignal *errorSignal;
	__block RACSignal *completedSignal;

	beforeEach(^{
		subject = [RACReplaySubject subject];

		oneSignal = [RACSignal return:@1];
		twoSignal = [RACSignal return:@2];
		threeSignal = [RACSignal return:@3];

		errorSignal = [RACSignal error:RACSignalTestError];
		completedSignal = RACSignal.empty;
	});

	it(@"should concatenate the values of inner signals", ^{
		[subject sendNext:oneSignal];
		[subject sendNext:twoSignal];
		[subject sendNext:completedSignal];
		[subject sendNext:threeSignal];

		NSMutableArray *values = [NSMutableArray array];
		[[subject concat] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		NSArray *expected = @[ @1, @2, @3 ];
		expect(values).to.equal(expected);
	});

	it(@"should complete only after all signals complete", ^{
		RACReplaySubject *valuesSubject = [RACReplaySubject subject];

		[subject sendNext:valuesSubject];
		[subject sendCompleted];

		[valuesSubject sendNext:@1];
		[valuesSubject sendNext:@2];
		[valuesSubject sendCompleted];

		NSArray *expected = @[ @1, @2 ];
		expect([[subject concat] toArray]).to.equal(expected);
	});

	it(@"should pass through errors", ^{
		[subject sendNext:errorSignal];
		
		NSError *error = nil;
		[[subject concat] firstOrDefault:nil success:NULL error:&error];
		expect(error).to.equal(RACSignalTestError);
	});
});


describe(@"-finally:", ^{
	__block RACSubject *subject;

	__block BOOL finallyInvoked;
	__block RACSignal *signal;

	beforeEach(^{
		subject = [RACSubject subject];
		
		finallyInvoked = NO;
		signal = [subject finally:^{
			finallyInvoked = YES;
		}];
	});

	it(@"should not run finally without a subscription", ^{
		[subject sendCompleted];
		expect(finallyInvoked).to.beFalsy();
	});

	describe(@"with a subscription", ^{
		__block RACDisposable *disposable;

		beforeEach(^{
			disposable = [signal subscribeCompleted:^{}];
		});
		
		afterEach(^{
			[disposable dispose];
		});

		it(@"should not run finally upon next", ^{
			[subject sendNext:RACUnit.defaultUnit];
			expect(finallyInvoked).to.beFalsy();
		});

		it(@"should run finally upon completed", ^{
			[subject sendCompleted];
			expect(finallyInvoked).to.beTruthy();
		});

		it(@"should run finally upon error", ^{
			[subject sendError:nil];
			expect(finallyInvoked).to.beTruthy();
		});
	});
});

describe(@"-ignoreElements", ^{
	__block RACSubject *subject;

	__block BOOL gotNext;
	__block BOOL gotCompleted;
	__block NSError *receivedError;

	beforeEach(^{
		subject = [RACSubject subject];

		gotNext = NO;
		gotCompleted = NO;
		receivedError = nil;

		[[subject ignoreElements] subscribeNext:^(id _) {
			gotNext = YES;
		} error:^(NSError *error) {
			receivedError = error;
		} completed:^{
			gotCompleted = YES;
		}];
	});

	it(@"should skip nexts and pass through completed", ^{
		[subject sendNext:RACUnit.defaultUnit];
		[subject sendCompleted];

		expect(gotNext).to.beFalsy();
		expect(gotCompleted).to.beTruthy();
		expect(receivedError).to.beNil();
	});

	it(@"should skip nexts and pass through errors", ^{
		[subject sendNext:RACUnit.defaultUnit];
		[subject sendError:RACSignalTestError];

		expect(gotNext).to.beFalsy();
		expect(gotCompleted).to.beFalsy();
		expect(receivedError).to.equal(RACSignalTestError);
	});
});

describe(@"-materialize", ^{
	it(@"should convert nexts and completed into RACEvents", ^{
		NSArray *events = [[[RACSignal return:RACUnit.defaultUnit] materialize] toArray];
		NSArray *expected = @[
			[RACEvent eventWithValue:RACUnit.defaultUnit],
			RACEvent.completedEvent
		];

		expect(events).to.equal(expected);
	});

	it(@"should convert errors into RACEvents and complete", ^{
		NSArray *events = [[[RACSignal error:RACSignalTestError] materialize] toArray];
		NSArray *expected = @[ [RACEvent eventWithError:RACSignalTestError] ];
		expect(events).to.equal(expected);
	});
});

describe(@"-dematerialize", ^{
	it(@"should convert nexts from RACEvents", ^{
		RACSignal *events = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendNext:[RACEvent eventWithValue:@2]];
			[subscriber sendCompleted];
			return nil;
		}];

		NSArray *expected = @[ @1, @2 ];
		expect([[events dematerialize] toArray]).to.equal(expected);
	});

	it(@"should convert completed from a RACEvent", ^{
		RACSignal *events = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendNext:RACEvent.completedEvent];
			[subscriber sendNext:[RACEvent eventWithValue:@2]];
			[subscriber sendCompleted];
			return nil;
		}];

		NSArray *expected = @[ @1 ];
		expect([[events dematerialize] toArray]).to.equal(expected);
	});

	it(@"should convert error from a RACEvent", ^{
		RACSignal *events = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendNext:[RACEvent eventWithError:RACSignalTestError]];
			[subscriber sendNext:[RACEvent eventWithValue:@1]];
			[subscriber sendCompleted];
			return nil;
		}];

		__block NSError *error = nil;
		expect([[events dematerialize] firstOrDefault:nil success:NULL error:&error]).to.beNil();
		expect(error).to.equal(RACSignalTestError);
	});
});

SpecEnd
