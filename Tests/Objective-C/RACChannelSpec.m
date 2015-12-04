//
//  RACChannelSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "RACChannelExamples.h"

#import "NSObject+RACDeallocating.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal.h"

QuickSpecBegin(RACChannelSpec)

qck_describe(@"RACChannel", ^{
	qck_itBehavesLike(RACChannelExamples, ^{
		return @{
			RACChannelExampleCreateBlock: [^{
				return [[RACChannel alloc] init];
			} copy]
		};
	});
	
	qck_describe(@"memory management", ^{
		qck_it(@"should dealloc when its subscribers are disposed", ^{
			RACDisposable *leadingDisposable = nil;
			RACDisposable *followingDisposable = nil;

			__block BOOL deallocated = NO;

			@autoreleasepool {
				RACChannel *channel __attribute__((objc_precise_lifetime)) = [[RACChannel alloc] init];
				[channel.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				leadingDisposable = [channel.leadingTerminal subscribeCompleted:^{}];
				followingDisposable = [channel.followingTerminal subscribeCompleted:^{}];
			}

			[leadingDisposable dispose];
			[followingDisposable dispose];
			expect(@(deallocated)).toEventually(beTruthy());
		});
		
		qck_it(@"should dealloc when its subscriptions are disposed", ^{
			RACDisposable *leadingDisposable = nil;
			RACDisposable *followingDisposable = nil;

			__block BOOL deallocated = NO;

			@autoreleasepool {
				RACChannel *channel __attribute__((objc_precise_lifetime)) = [[RACChannel alloc] init];
				[channel.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					deallocated = YES;
				}]];

				leadingDisposable = [[RACSignal never] subscribe:channel.leadingTerminal];
				followingDisposable = [[RACSignal never] subscribe:channel.followingTerminal];
			}

			[leadingDisposable dispose];
			[followingDisposable dispose];
			expect(@(deallocated)).toEventually(beTruthy());
		});
	});
});

QuickSpecEnd
