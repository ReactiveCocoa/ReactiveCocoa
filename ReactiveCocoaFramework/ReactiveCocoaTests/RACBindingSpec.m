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
			RACDisposable *leadingDisposable = nil;
			RACDisposable *followingDisposable = nil;

			__block BOOL deallocated = NO;

			@autoreleasepool {
				RACBinding *binding __attribute__((objc_precise_lifetime)) = [[RACBinding alloc] init];
				[binding.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				leadingDisposable = [binding.leadingEndpoint subscribeCompleted:^{}];
				followingDisposable = [binding.followingEndpoint subscribeCompleted:^{}];
			}

			[leadingDisposable dispose];
			[followingDisposable dispose];
			expect(deallocated).will.beTruthy();
		});
		
		it(@"should dealloc when its subscriptions are disposed", ^{
			RACDisposable *leadingDisposable = nil;
			RACDisposable *followingDisposable = nil;

			__block BOOL deallocated = NO;

			@autoreleasepool {
				RACBinding *binding __attribute__((objc_precise_lifetime)) = [[RACBinding alloc] init];
				[binding.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				leadingDisposable = [[RACSignal never] subscribe:binding.leadingEndpoint];
				followingDisposable = [[RACSignal never] subscribe:binding.followingEndpoint];
			}

			[leadingDisposable dispose];
			[followingDisposable dispose];
			expect(deallocated).will.beTruthy();
		});
	});
});

SpecEnd
