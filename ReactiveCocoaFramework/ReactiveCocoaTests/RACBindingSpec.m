//
//  RACBindingSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBindingExamples.h"

#import "NSObject+RACDeallocating.h"
#import "RACBinding.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"

SpecBegin(RACBinding)

describe(@"RACBinding", ^{
	itShouldBehaveLike(RACBindingExamples, @{
		RACBindingExampleCreateBlock: [^{
			return [[RACBinding alloc] init];
		} copy]
	});
	
	describe(@"memory management", ^{
		it(@"should dealloc when its subscribers are disposed", ^{
			RACDisposable *factsDisposable = nil;
			RACDisposable *rumorsDisposable = nil;

			__block BOOL deallocated = NO;

			@autoreleasepool {
				RACBinding *binding __attribute__((objc_precise_lifetime)) = [[RACBinding alloc] init];
				[binding.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				factsDisposable = [binding.factsSignal subscribeCompleted:^{}];
				rumorsDisposable = [binding.rumorsSignal subscribeCompleted:^{}];
			}

			[factsDisposable dispose];
			[rumorsDisposable dispose];
			expect(deallocated).will.beTruthy();
		});
		
		it(@"should dealloc when its subscriptions are disposed", ^{
			RACDisposable *factsDisposable = nil;
			RACDisposable *rumorsDisposable = nil;

			__block BOOL deallocated = NO;

			@autoreleasepool {
				RACBinding *binding __attribute__((objc_precise_lifetime)) = [[RACBinding alloc] init];
				[binding.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				factsDisposable = [[RACSignal never] subscribe:binding.factsSubscriber];
				rumorsDisposable = [[RACSignal never] subscribe:binding.rumorsSubscriber];
			}

			[factsDisposable dispose];
			[rumorsDisposable dispose];
			expect(deallocated).will.beTruthy();
		});
		
		it(@"should dealloc when bidirectional subscriptions with other bindings are disposed", ^{
			RACDisposable *factsDisposable = nil;
			RACDisposable *rumorsDisposable = nil;

			__block BOOL deallocated1 = NO;
			__block BOOL deallocated2 = NO;

			@autoreleasepool {
				RACBinding *binding1 __attribute__((objc_precise_lifetime)) = [[RACBinding alloc] init];
				[binding1.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated1 = YES;
				}]];

				RACBinding *binding2 __attribute__((objc_precise_lifetime)) = [[RACBinding alloc] init];
				[binding2.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated2 = YES;
				}]];

				factsDisposable = [binding1.factsSignal subscribe:binding2.factsSubscriber];
				rumorsDisposable = [binding2.rumorsSignal subscribe:binding1.rumorsSubscriber];
			}

			[factsDisposable dispose];
			[rumorsDisposable dispose];

			expect(deallocated1).will.beTruthy();
			expect(deallocated2).will.beTruthy();
		});
	});
});

SpecEnd
