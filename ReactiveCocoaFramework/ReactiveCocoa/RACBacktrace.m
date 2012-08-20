//
//  RACBacktrace.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-16.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <execinfo.h>
#import <pthread.h>
#import "RACBacktrace.h"

@interface RACBacktrace ()

// The backtrace from any previous thread.
@property (nonatomic, strong, readwrite) RACBacktrace *previousThreadBacktrace;

// The call stack of this backtrace's thread.
@property (nonatomic, copy, readwrite) NSArray *callStackSymbols;

// Captures the current thread's backtrace, appending it to any backtrace from
// a previous thread.
+ (instancetype)captureBacktrace;

// Same as +captureBacktrace, but omits the specified number of frames at the
// top of the stack (in addition to this method itself).
+ (instancetype)captureBacktraceIgnoringFrames:(NSUInteger)ignoreCount;

// Prints the backtrace of the current thread, appended to that of any previous
// threads.
+ (void)printBacktrace;
@end

// Always inline this function, for consistency in backtraces.
__attribute__((always_inline))
static dispatch_block_t RACBacktraceBlock (dispatch_queue_t queue, dispatch_block_t block) {
	RACBacktrace *backtrace = [RACBacktrace captureBacktrace];

	return [^{
		dispatch_queue_set_specific(queue, (void *)pthread_self(), (void *)CFBridgingRetain(backtrace), (dispatch_function_t)&CFBridgingRelease);
		block();
		dispatch_queue_set_specific(queue, (void *)pthread_self(), NULL, NULL);
	} copy];
}

// TODO: function pointer variants

void rac_dispatch_async (dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_async(queue, RACBacktraceBlock(queue, block));
}

void rac_dispatch_barrier_async (dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_barrier_async(queue, RACBacktraceBlock(queue, block));
}

void rac_dispatch_after (dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_after(time, queue, RACBacktraceBlock(queue, block));
}

// This is what actually performs the injection.
//
// The DYLD_INSERT_LIBRARIES environment variable must include the RAC dynamic
// library in order for this to work.
__attribute__((used)) static struct { const void *replacement; const void *replacee; } interposers[] __attribute__((section("__DATA,__interpose"))) = {
	{ (const void *)&rac_dispatch_async, (const void *)&dispatch_async },
	{ (const void *)&rac_dispatch_barrier_async, (const void *)&dispatch_barrier_async },
	{ (const void *)&rac_dispatch_after, (const void *)&dispatch_after },
};

static void RACSignalHandler (int sig) {
	[RACBacktrace printBacktrace];

	// Restore the default action and raise the signal again.
	signal(sig, SIG_DFL);
	raise(sig);
}

static void RACExceptionHandler (NSException *ex) {
	[RACBacktrace printBacktrace];
}

@implementation RACBacktrace

#pragma mark Initialization

+ (void)load {
	@autoreleasepool {
		NSString *libraries = [[[NSProcessInfo processInfo] environment] objectForKey:@"DYLD_INSERT_LIBRARIES"];

		// Don't install our handlers if we're not actually intercepting function
		// calls.
		if ([libraries rangeOfString:@"ReactiveCocoa"].length == 0) return;

		NSLog(@"*** Enabling asynchronous backtraces");

		NSSetUncaughtExceptionHandler(&RACExceptionHandler);
	}

	signal(SIGILL, &RACSignalHandler);
	signal(SIGTRAP, &RACSignalHandler);
	signal(SIGABRT, &RACSignalHandler);
	signal(SIGFPE, &RACSignalHandler);
	signal(SIGBUS, &RACSignalHandler);
	signal(SIGSEGV, &RACSignalHandler);
	signal(SIGSYS, &RACSignalHandler);
	signal(SIGPIPE, &RACSignalHandler);
}

#pragma mark Backtraces

+ (instancetype)captureBacktrace {
	return [self captureBacktraceIgnoringFrames:1];
}

+ (instancetype)captureBacktraceIgnoringFrames:(NSUInteger)ignoreCount {
	RACBacktrace *oldBacktrace = (__bridge id)dispatch_get_specific((void *)pthread_self());

	RACBacktrace *newBacktrace = [[RACBacktrace alloc] init];
	newBacktrace.previousThreadBacktrace = oldBacktrace;

	NSArray *symbols = [NSThread callStackSymbols];

	// Omit this method plus however many others from the backtrace.
	if (symbols.count > ignoreCount + 1) {
		newBacktrace.callStackSymbols = [symbols subarrayWithRange:NSMakeRange(ignoreCount + 1, symbols.count - ignoreCount - 1)];
	}

	return newBacktrace;
}

+ (void)printBacktrace {
	@autoreleasepool {
		NSLog(@"Backtrace: %@", [self captureBacktraceIgnoringFrames:1]);
		fflush(stdout);
	}
}

#pragma mark NSObject

- (NSString *)description {
	NSString *str = [NSString stringWithFormat:@"%@", self.callStackSymbols];
	if (self.previousThreadBacktrace != nil) {
		str = [str stringByAppendingFormat:@"\n\n... asynchronously invoked from: %@", self.previousThreadBacktrace];
	}

	return str;
}

@end
