//
//  RACBacktraceSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-12-24.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBacktrace.h"

#import "NSArray+RACSequenceAdditions.h"
#import "RACReplaySubject.h"
#import "RACScheduler.h"
#import "RACSequence.h"
#import "RACSignal+Operations.h"

#ifdef RAC_DEBUG_BACKTRACE

static RACBacktrace *previousBacktrace;

static void capturePreviousBacktrace(void *context) {
	previousBacktrace = [RACBacktrace backtrace].previousThreadBacktrace;
}

typedef struct {
	dispatch_queue_t queue;
	NSUInteger i;
	__unsafe_unretained RACSubject *doneSubject;
} RACDeepRecursionContext;

static void recurseDeeply(void *ptr) {
	RACDeepRecursionContext *context = ptr;

	if (context->i++ < 10000) {
		rac_dispatch_async_f(context->queue, context, recurseDeeply);
	} else {
		[context->doneSubject sendCompleted];
	}
}

SpecBegin(RACBacktrace)

__block dispatch_block_t block;

beforeEach(^{
	expect([RACBacktrace backtrace].previousThreadBacktrace).to.beNil();
	previousBacktrace = nil;

	block = ^{
		capturePreviousBacktrace(NULL);
	};
});

it(@"should capture the current backtrace", ^{
	RACBacktrace *backtrace = [RACBacktrace backtrace];
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

	it(@"shouldn't overflow the stack when deallocating a huge backtrace list", ^{
		RACSubject *doneSubject = [RACReplaySubject subject];
		RACDeepRecursionContext context = {
			.queue = queue,
			.i = 0,
			.doneSubject = doneSubject
		};

		rac_dispatch_async_f(queue, &context, &recurseDeeply);
		[doneSubject waitUntilCompleted:NULL];
	});
});

it(@"should trace across a RACScheduler", ^{
	[[RACScheduler scheduler] schedule:block];
	expect(previousBacktrace).willNot.beNil();
});

it(@"shouldn't go bonkers with RACScheduler", ^{
	NSMutableArray *a = [NSMutableArray array];
	for (NSUInteger i = 0; i < 5000; i++) {
		[a addObject:@(i)];
	}

	[[a.rac_sequence signalWithScheduler:[RACScheduler scheduler]] subscribeCompleted:^{}];
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
