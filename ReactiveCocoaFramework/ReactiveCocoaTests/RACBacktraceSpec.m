//
//  RACBacktraceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-12-24.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBacktrace.h"
#import "RACScheduler.h"

extern void rac_dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
extern void rac_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block);
extern void rac_dispatch_after(dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block);
extern void rac_dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function);
extern void rac_dispatch_barrier_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function);
extern void rac_dispatch_after_f(dispatch_time_t time, dispatch_queue_t queue, void *context, dispatch_function_t function);

#ifdef DEBUG

static RACBacktrace *previousBacktrace;

static void capturePreviousBacktrace(void *context) {
	previousBacktrace = [RACBacktrace captureBacktrace].previousThreadBacktrace;
}

SpecBegin(RACBacktrace)

__block dispatch_block_t block;

beforeEach(^{
	expect([RACBacktrace captureBacktrace].previousThreadBacktrace).to.beNil();
	previousBacktrace = nil;

	block = ^{
		capturePreviousBacktrace(NULL);
	};
});

it(@"should capture the current backtrace", ^{
	RACBacktrace *backtrace = [RACBacktrace captureBacktrace];
	expect(backtrace).notTo.beNil();
});

describe(@"with a GCD queue", ^{
	__block dispatch_queue_t queue;

	beforeEach(^{
		queue = dispatch_queue_create("com.github.ReactiveCocoa.RACBacktraceSpec", DISPATCH_QUEUE_SERIAL);
	});

	afterEach(^{
		dispatch_barrier_sync(queue, ^{});
		dispatch_release(queue);
	});

	it(@"should trace across dispatch_async", ^{
		rac_dispatch_async(queue, block);
		expect(previousBacktrace).willNot.beNil();
	});

	it(@"should trace across dispatch_async to the main thread", ^{
		rac_dispatch_async(queue, ^{
			rac_dispatch_async(dispatch_get_main_queue(), block);
		});

		expect(previousBacktrace).willNot.beNil();
	});

	it(@"should trace across dispatch_async_f", ^{
		rac_dispatch_async_f(queue, NULL, &capturePreviousBacktrace);
		expect(previousBacktrace).willNot.beNil();
	});

	it(@"should trace across dispatch_barrier_async", ^{
		rac_dispatch_barrier_async(queue, block);
		expect(previousBacktrace).willNot.beNil();
	});

	it(@"should trace across dispatch_barrier_async_f", ^{
		rac_dispatch_barrier_async_f(queue, NULL, &capturePreviousBacktrace);
		expect(previousBacktrace).willNot.beNil();
	});

	it(@"should trace across dispatch_after", ^{
		rac_dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1), queue, block);
		expect(previousBacktrace).willNot.beNil();
	});

	it(@"should trace across dispatch_after_f", ^{
		rac_dispatch_after_f(dispatch_time(DISPATCH_TIME_NOW, 1), queue, NULL, &capturePreviousBacktrace);
		expect(previousBacktrace).willNot.beNil();
	});
});

it(@"should trace across a RACScheduler", ^{
	[[RACScheduler scheduler] schedule:block];
	expect(previousBacktrace).willNot.beNil();
});

// Tracing across NSOperationQueue only works on OS X because it depends on
// interposing through dynamic linking
#ifndef __IPHONE_OS_VERSION_MIN_REQUIRED
	it(@"should trace across an NSOperationQueue", ^{
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		[queue addOperationWithBlock:block];
		expect(previousBacktrace).willNot.beNil();
	});
#endif

SpecEnd

#endif
