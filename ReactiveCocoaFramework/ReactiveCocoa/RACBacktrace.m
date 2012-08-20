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

typedef struct {
	const void *replacement;
	const void *replacee;
} rac_interpose_t;

@interface RACBacktrace ()
@property (nonatomic, strong, readwrite) RACBacktrace *previousThreadBacktrace;
@property (nonatomic, copy, readwrite) NSArray *callStackSymbols;

+ (instancetype)captureBacktrace;
+ (void)printBacktrace;
@end

static dispatch_block_t rac_backtrace_block (dispatch_queue_t queue, dispatch_block_t block) {
	RACBacktrace *backtrace = [RACBacktrace captureBacktrace];

	return [^{
		dispatch_queue_set_specific(queue, (void *)pthread_self(), (void *)CFBridgingRetain(backtrace), (dispatch_function_t)&CFBridgingRelease);
		block();
		dispatch_queue_set_specific(queue, (void *)pthread_self(), NULL, NULL);
	} copy];
}

// TODO: function pointer variants

void rac_dispatch_async (dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_async(queue, rac_backtrace_block(queue, block));
}

void rac_dispatch_barrier_async (dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_barrier_async(queue, rac_backtrace_block(queue, block));
}

void rac_dispatch_after (dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_after(time, queue, rac_backtrace_block(queue, block));
}

__attribute__((used)) static rac_interpose_t interposers[] __attribute__((section("__DATA,__interpose"))) = {
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
	NSString *libraries = [[[NSProcessInfo processInfo] environment] objectForKey:@"DYLD_INSERT_LIBRARIES"];

	// Don't install our handlers if we're not actually intercepting function
	// calls.
	if ([libraries rangeOfString:@"ReactiveCocoa"].length == 0) return;

	NSLog(@"*** Enabling asynchronous backtraces");

	NSSetUncaughtExceptionHandler(&RACExceptionHandler);

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
	RACBacktrace *oldBacktrace = (__bridge id)dispatch_get_specific((void *)pthread_self());

	RACBacktrace *newBacktrace = [[RACBacktrace alloc] init];
	newBacktrace.previousThreadBacktrace = oldBacktrace;
	newBacktrace.callStackSymbols = [NSThread callStackSymbols];

	return newBacktrace;
}

+ (void)printBacktrace {
	NSLog(@"Backtrace: %@", [self captureBacktrace]);
	fflush(stdout);
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
