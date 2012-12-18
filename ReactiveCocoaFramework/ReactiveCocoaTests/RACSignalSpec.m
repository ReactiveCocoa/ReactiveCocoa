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
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSignal.h"
#import "RACSubject.h"
#import "RACSubscriber.h"
#import "RACTestObject.h"
#import "RACTuple.h"
#import "RACUnit.h"

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

describe(@"<RACStream>", ^{
	id verifyValues = ^(id<RACSignal> signal, NSArray *expectedValues) {
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

	id<RACSignal> infiniteSignal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
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

	itShouldBehaveLike(RACStreamExamples, @{
		RACStreamExamplesClass: RACSignal.class,
		RACStreamExamplesVerifyValuesBlock: verifyValues,
		RACStreamExamplesInfiniteStream: infiniteSignal
	}, nil);
});

describe(@"subscribing", ^{
	__block id<RACSignal> signal = nil;
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
		id<RACSignal> signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
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
	it(@"should dispose of the disposable returned from the didSubscribe block", ^{
		__block BOOL innerDisposed = NO;
		id<RACSignal> signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
			return [RACDisposable disposableWithBlock:^{
				innerDisposed = YES;
			}];
		}];

		__block RACDisposable *disposable = [signal subscribeNext:^(id x) {}];
		[disposable dispose];

		expect(innerDisposed).to.beTruthy();

		innerDisposed = NO;
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			disposable = [signal subscribeNext:^(id x) {}];
			[disposable dispose];
		});

		expect(innerDisposed).will.beTruthy();
	});
});

describe(@"querying", ^{
	__block id<RACSignal> signal = nil;
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
		id<RACSignal> signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
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
		
		id<RACSignal> window = [signal windowWithStart:windowOpen close:^(id<RACSignal> start) {
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
		id<RACSignal> signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
		id<RACSignal> signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
		NSError *testError = [NSError errorWithDomain:@"foo" code:100 userInfo:nil];
		id<RACSignal> signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[subscriber sendError:testError];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error).to.equal(testError);
	});

	it(@"shouldn't crash when returning an error from a background scheduler", ^{
		static NSString * const errorDomain = @"foo";
		static const NSInteger errorCode = 100;
		id<RACSignal> signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
			[[RACScheduler scheduler] schedule:^{
				[subscriber sendError:[NSError errorWithDomain:errorDomain code:errorCode userInfo:nil]];
			}];
			return nil;
		}];

		expect(signal).notTo.beNil();

		__block BOOL success = NO;
		__block NSError *error = nil;
		expect([signal firstOrDefault:@5 success:&success error:&error]).to.equal(@5);
		expect(success).to.beFalsy();
		expect(error.domain).to.equal(errorDomain);
		expect(error.code).to.equal(errorCode);
	});
});

describe(@"continuation", ^{
	it(@"shouldn't receive deferred errors", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		id<RACSignal> signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			if(numberOfSubscriptions > 2) {
				[subscriber sendCompleted];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[subscriber sendNext:@"1"];
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			[subscriber sendCompleted];
			return nil;
		}];
		
		__block BOOL gotNext = NO;
		__block BOOL gotError = NO;
		[[signal asMaybes] subscribeNext:^(id x) {
			gotNext = YES;
		} error:^(NSError *error) {
			gotError = YES;
		} completed:^{
			
		}];
		
		expect(gotNext).to.beTruthy();
		expect(gotError).to.beFalsy();
	});
	
	it(@"should repeat after completion", ^{
		__block NSUInteger numberOfSubscriptions = 0;
		id<RACSignal> signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			if(numberOfSubscriptions > 2) {
				[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
				return nil;
			}
			
			numberOfSubscriptions++;
			
			[subscriber sendNext:@"1"];
			[subscriber sendCompleted];
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
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
		id<RACSignal> signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
		id<RACSignal> signal = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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

describe(@"+combineLatest:", ^{
	__block id<RACSubscriber> subscriber1 = nil;
	__block id<RACSubscriber> subscriber2 = nil;
	__block id<RACSignal> signal1 = nil;
	__block id<RACSignal> signal2 = nil;
	__block id<RACSignal> combined = nil;
	
	beforeEach(^{
		signal1 = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			subscriber1 = subscriber;
			return nil;
		}],
		signal2 = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			subscriber2 = subscriber;
			return nil;
		}],
		combined = [RACSignal combineLatest:@[ signal1, signal2 ]];
	});
	
	it(@"should yield when all sources yield", ^{
		__block id result;
		
		[combined subscribeNext:^(id x) {
			result = x;
		}];
		
		[subscriber1 sendNext:@"1"];
		[subscriber2 sendNext:@"2"];
		
		expect(result).to.beKindOf([RACTuple class]);
		RACTuple *tuple = result;
		expect(tuple.first).to.equal(@"1");
		expect(tuple.second).to.equal(@"2");
	});
	
	it(@"should not yield when some sources have not yielded", ^{
		__block id result;
		
		[combined subscribeNext:^(id x) {
			result = x;
		}];
		
		[subscriber1 sendNext:@"1"];
		
		expect(result).to.beNil();
	});
	
	it(@"should yield multiple times when any sources yield multiple times", ^{
		NSMutableArray *results = [NSMutableArray array];
		[combined subscribeNext:^(id x) {
			[results addObject:x];
		}];
		
		[subscriber1 sendNext:@"1"];
		[subscriber2 sendNext:@"2"];
		
		[subscriber1 sendNext:@"3"];
		[subscriber2 sendNext:@"4"];
		
		RACTuple *result1 = [results objectAtIndex:0];
		expect(result1.first).to.equal(@"1");
		expect(result1.second).to.equal(@"2");
		
		RACTuple *result2 = [results objectAtIndex:1];
		expect(result2.first).to.equal(@"3");
		expect(result2.second).to.equal(@"2");
		
		RACTuple *result3 = [results objectAtIndex:2];
		expect(result3.first).to.equal(@"3");
		expect(result3.second).to.equal(@"4");
	});
	
	it(@"should complete when all sources complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];
		
		[subscriber1 sendCompleted];
		[subscriber2 sendCompleted];
		
		expect(completed).to.beTruthy();
	});
	
	it(@"should not complete when some sources are not complete", ^{
		__block BOOL completed = NO;
		
		[combined subscribeCompleted:^{
			completed = YES;
		}];
		
		[subscriber1 sendCompleted];
		
		expect(completed).to.beFalsy();
	});
	
	it(@"should error when a source errors", ^{
		__block BOOL gotError = NO;
		
		[combined subscribeError:^(NSError *error) {
			gotError = YES;
		}];
		
		[subscriber1 sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		
		expect(gotError).to.beTruthy();
	});
	
	it(@"should error only once when multiple sources error", ^{
		__block int errorCount = 0;
		
		[combined subscribeError:^(NSError *error) {
			errorCount++;
		}];
		
		[subscriber1 sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		[subscriber2 sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		
		expect(errorCount).to.equal(1);
	});

	it(@"should complete immediately when not given any signals", ^{
		id<RACSignal> signal = [RACSignal combineLatest:@[]];

		__block BOOL completed = NO;
		[signal subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beTruthy();
	});
});

describe(@"+combineLatest:reduce:", ^{
	__block RACSubject *subject1;
	__block RACSubject *subject2;

	beforeEach(^{
		subject1 = [RACSubject subject];
		subject2 = [RACSubject subject];
	});

	it(@"should send a RACTuple when given a nil reduce block", ^{
		id<RACSignal> combined = [RACSignal combineLatest:@[ subject1, subject2 ] reduce:nil];

		__block id received;
		[combined subscribeNext:^(id x) {
			received = x;
		}];

		[subject1 sendNext:@1];
		[subject2 sendNext:@2];

		RACTuple *expected = [RACTuple tupleWithObjects:@1, @2, nil];
		expect(received).to.equal(expected);
	});

	it(@"should send nils for nil values", ^{
		__block id receivedVal1;
		__block id receivedVal2;
		id<RACSignal> combined = [RACSignal combineLatest:@[ subject1, subject2 ] reduce:^(id val1, id val2) {
			receivedVal1 = val1;
			receivedVal2 = val2;
			return nil;
		}];

		__block BOOL gotValue = NO;
		[combined subscribeNext:^(id x) {
			gotValue = YES;
		}];

		[subject1 sendNext:nil];
		[subject2 sendNext:nil];

		expect(gotValue).to.beTruthy();
		expect(receivedVal1).to.beNil();
		expect(receivedVal2).to.beNil();
	});

	it(@"should send the return result of the reduce block", ^{
		id<RACSignal> combined = [RACSignal combineLatest:@[ subject1, subject2 ] reduce:^(NSString *string1, NSString *string2) {
			return [NSString stringWithFormat:@"%@: %@", string1, string2];
		}];

		__block id received;
		[combined subscribeNext:^(id x) {
			received = x;
		}];

		[subject1 sendNext:@"hello"];
		[subject2 sendNext:@"world"];

		expect(received).to.equal(@"hello: world");
	});

	it(@"should only complete after all its signals complete", ^{
		id<RACSignal> combined = [RACSignal combineLatest:@[ subject1, subject2 ] reduce:nil];

		__block BOOL completed = NO;
		[combined subscribeCompleted:^{
			completed = YES;
		}];

		expect(completed).to.beFalsy();

		[subject1 sendNext:@1];
		[subject2 sendNext:@2];

		expect(completed).to.beFalsy();

		[subject1 sendCompleted];

		expect(completed).to.beFalsy();

		[subject2 sendCompleted];

		expect(completed).will.beTruthy();
	});
	
	it(@"should handle multiples of the same signals", ^{
		id<RACSignal> combined = [RACSignal combineLatest:@[ subject1, subject2, subject1, subject2 ] reduce:^ NSString * (NSString *string1, NSString *string2, NSString *string3, NSString *string4) {
			return [NSString stringWithFormat:@"%@ : %@ = %@ : %@", string1, string2, string3, string4];
		}];
		
		NSMutableArray *receivedValues = NSMutableArray.array;
		
		[combined subscribeNext:^(id x) {
			[receivedValues addObject:x];
		}];
		
		[subject1 sendNext:@"apples"];
		expect(receivedValues.lastObject).to.beNil();
		
		[subject2 sendNext:@"oranges"];
		expect(receivedValues.lastObject).to.equal(@"apples : oranges = apples : oranges");
		
		[subject1 sendNext:@"horses"];
		[subject2 sendNext:@"cattle"];
		expect(receivedValues.lastObject).to.equal(@"horses : cattle = horses : cattle");
	});
    
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		id<RACSignal> sideEffectingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			++counter;
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];
		id<RACSignal> combined = [RACSignal combineLatest:@[ sideEffectingSignal, sideEffectingSignal ] reduce:^ NSString * (id x, id y) {
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

describe(@"distinctUntilChanged", ^{
	it(@"should only send values that are distinct from the previous value", ^{
		id<RACSignal> sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
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
		id<RACSignal> sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
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
		id<RACSignal> sub = [[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
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
	id setupBlock = ^(RACTestObject *testObject, NSString *keyPath, id<RACSignal> signal) {
		[signal toProperty:keyPath onObject:testObject];
	};

	itShouldBehaveLike(RACPropertySignalExamples, @{ RACPropertySignalExamplesSetupBlock: setupBlock }, nil);

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
			NSObject<RACSignal> *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
			NSObject<RACSignal> *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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

			NSObject<RACSignal> *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
				NSObject<RACSignal> *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
				NSObject<RACSignal> *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
				NSObject<RACSignal> *signal __attribute__((objc_precise_lifetime)) = [RACSignal createSignal:^ id (id<RACSubscriber> subscriber) {
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
				id<RACSignal> intermediateSignal = [subject doNext:^(id _) {
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
	__block id<RACSignal> merged;
	beforeEach(^{
		sub1 = [RACSubject subject];
		sub2 = [RACSubject subject];
		merged = [RACSignal merge:@[ sub1, sub2 ]];
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

		NSError *error = [NSError errorWithDomain:@"" code:0 userInfo:nil];
		[sub1 sendError:error];

		expect(errorReceived).to.equal(error);
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
		id<RACSignal> signal = [RACSignal merge:@[]];

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
	__block id<RACSignal> sub1;
	__block id<RACSignal> sub2;
	__block id<RACSignal> sub3;
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

		itShouldBehaveLike(RACSignalMergeConcurrentCompletionExampleGroup, @{ RACSignalMaxConcurrent: @0 }, nil);
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

		itShouldBehaveLike(RACSignalMergeConcurrentCompletionExampleGroup, @{ RACSignalMaxConcurrent: @1 }, nil);
	});
});

describe(@"-switch", ^{
	it(@"should send values from the most recent signal", ^{
		RACSubject *subject = [RACSubject subject];
		NSMutableArray *values = [NSMutableArray array];
		[[subject switch] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			return nil;
		}]];

		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@3];
			[subscriber sendNext:@4];
			[subscriber sendCompleted];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2, @3, @4 ];
		expect(values).to.equal(expected);
	});

	it(@"should accept nil signals", ^{
		RACSubject *subject = [RACSubject subject];
		NSMutableArray *values = [NSMutableArray array];
		[[subject switch] subscribeNext:^(id x) {
			[values addObject:x];
		}];

		[subject sendNext:nil];

		[subject sendNext:[RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendCompleted];
			return nil;
		}]];

		NSArray *expected = @[ @1, @2 ];
		expect(values).to.equal(expected);
	});
});

describe(@"+interval:", ^{
	static const NSTimeInterval interval = 0.1;
	void (^expectItToWorkWithScheduler)(RACScheduler *) = ^(RACScheduler *scheduler) {
		__block volatile int32_t nextsReceived = 0;
		[scheduler schedule:^{
			__block NSTimeInterval lastTime = NSDate.timeIntervalSinceReferenceDate;
			[[[RACSignal interval:interval] take:3] subscribeNext:^(id _) {
				NSTimeInterval currentTime = NSDate.timeIntervalSinceReferenceDate;
				expect(currentTime - lastTime).beGreaterThanOrEqualTo(interval);

				OSAtomicAdd32Barrier(1, &nextsReceived);
			}];
		}];

		expect(nextsReceived).will.equal(3);
	};

	it(@"should fire repeatedly at every interval", ^{
		expectItToWorkWithScheduler(RACScheduler.mainThreadScheduler);
	});

	it(@"should work on a background scheduler", ^{
		expectItToWorkWithScheduler([RACScheduler scheduler]);
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
	id<RACSignal> signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		[subscriber sendNext:@1];
		[subscriber sendNext:@2];
		[subscriber sendNext:@3];
		[subscriber sendNext:@4];
		[subscriber sendCompleted];
		return nil;
	}];

	itShouldBehaveLike(RACSequenceExamples, @{ RACSequenceSequence: signal.sequence, RACSequenceExpectedValues: @[ @1, @2, @3, @4 ] }, nil);
});

it(@"should complete take: even if the original signal doesn't", ^{
	id<RACSignal> sendOne = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
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

describe(@"+zip:reduce:", ^{
	__block id<RACSignal> errorAfterTwo = nil;
	__block id<RACSignal> errorAfterThree = nil;
	__block id<RACSignal> completeAfterTwo = nil;
	__block id<RACSignal> completeAfterThree = nil;
	
	before(^{
		errorAfterTwo = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return nil;
		}];
		errorAfterThree = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
			return nil;
		}];
		completeAfterTwo = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendCompleted];
			return nil;
		}];
		completeAfterThree = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@3];
			[subscriber sendCompleted];
			return nil;
		}];
	});
	
	it(@"should ignore errors that occur after +zip:reduce: finishes", ^{
		__block NSError *receivedError = nil;
		
		[[RACSignal zip:@[ errorAfterThree, completeAfterTwo ] reduce:nil] subscribeError:^(NSError *error) {
			receivedError = error;
		}];
		
		expect(receivedError).to.beNil();
	});
	
	it(@"should send errors that occur before +zip:reduce: finishes", ^{
		__block NSError *receivedError = nil;
		
		[[RACSignal zip:@[ errorAfterTwo, completeAfterThree ] reduce:nil] subscribeError:^(NSError *error) {
			receivedError = error;
		}];
		
		expect(receivedError).notTo.beNil();
	});
	
	it(@"should ignore errors if +zip:reduce: would have finished regardless", ^{
		__block NSError *receivedError = nil;
		
		[[RACSignal zip:@[ errorAfterThree, completeAfterThree ] reduce:nil] subscribeError:^(NSError *error) {
			receivedError = error;
		}];
		
		expect(receivedError).to.beNil();
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
		[c sendError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
		
		// a: [===......]
		// b: [====C....]
		// c: [=====E...]
		
		expectedValues = @[ @"111", @"222", @"333" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.beNil();
		expect(hasCompleted).to.beFalsy();
		
		[a sendNext:@4];
		[a sendNext:@5];
		[a sendNext:@6];
		[a sendNext:@7];
		
		// a: [=======..]
		// b: [====C....]
		// c: [=====E...]
		
		expectedValues = @[ @"111", @"222", @"333", @"444" ];
		expect(receivedValues).to.equal(expectedValues);
		expect(receivedError).to.beNil();
		expect(hasCompleted).to.beTruthy();
	});
	
	it(@"should handle multiples of the same side-effecting signal", ^{
		__block NSUInteger counter = 0;
		id<RACSignal> sideEffectingSignal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			++counter;
			[subscriber sendNext:@1];
			[subscriber sendCompleted];
			return nil;
		}];
		id<RACSignal> combined = [RACSignal zip:@[ sideEffectingSignal, sideEffectingSignal ] reduce:^ NSString * (id x, id y) {
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
		id<RACSignal> sampled = [subject sample:sampleSubject];
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
		id<RACSignal> collected = [subject collect];

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

SpecEnd
