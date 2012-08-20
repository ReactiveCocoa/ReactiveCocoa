//
//  GCD+RACExtensions.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-16.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <execinfo.h>
#import <pthread.h>

typedef struct {
	const void *replacement;
	const void *replacee;
} rac_interpose_t;

@interface RACBacktrace : NSObject
@property (nonatomic, strong) RACBacktrace *previousThreadBacktrace;
@property (nonatomic, copy) NSArray *callStackSymbols;
@end

static dispatch_block_t rac_backtrace_block (dispatch_queue_t queue, dispatch_block_t block) {
	RACBacktrace *oldBacktrace = (__bridge id)dispatch_get_specific((void *)pthread_self());

	RACBacktrace *newBacktrace = [[RACBacktrace alloc] init];
	newBacktrace.previousThreadBacktrace = oldBacktrace;
	newBacktrace.callStackSymbols = [NSThread callStackSymbols];

	return [^{
		dispatch_queue_set_specific(queue, (void *)pthread_self(), (void *)CFBridgingRetain(newBacktrace), (dispatch_function_t)&CFBridgingRelease);
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

static void rac_print_async_backtrace (void) {
	RACBacktrace *lastBacktrace = (__bridge id)dispatch_get_specific((void *)pthread_self());

	RACBacktrace *newBacktrace = [[RACBacktrace alloc] init];
	newBacktrace.previousThreadBacktrace = lastBacktrace;
	newBacktrace.callStackSymbols = [NSThread callStackSymbols];

	NSLog(@"Backtrace: %@", newBacktrace);
	fflush(stdout);
}

static void rac_signal_handler (int sig) {
	rac_print_async_backtrace();
	exit(EXIT_FAILURE);
}

static void rac_exception_handler (NSException *ex) {
	NSLog(@"*** Uncaught exception: %@", ex);

	rac_print_async_backtrace();
	exit(EXIT_FAILURE);
}

__attribute__((constructor))
static void rac_install_handlers (void) {
	const char *libraries = getenv("DYLD_INSERT_LIBRARIES");

	// Don't install our handlers if we're not actually intercepting function
	// calls.
	if (libraries == NULL) return;
	if (strstr(libraries, "ReactiveCocoa") == NULL) return;

	NSLog(@"*** Enabling asynchronous backtraces");

	NSSetUncaughtExceptionHandler(&rac_exception_handler);

	signal(SIGILL, &rac_signal_handler);
	signal(SIGTRAP, &rac_signal_handler);
	signal(SIGABRT, &rac_signal_handler);
	signal(SIGFPE, &rac_signal_handler);
	signal(SIGBUS, &rac_signal_handler);
	signal(SIGSEGV, &rac_signal_handler);
	signal(SIGSYS, &rac_signal_handler);
	signal(SIGPIPE, &rac_signal_handler);
}

@implementation RACBacktrace

- (NSString *)description {
	NSString *str = [NSString stringWithFormat:@"%@", self.callStackSymbols];
	if (self.previousThreadBacktrace != nil) {
		str = [str stringByAppendingFormat:@"\n\n... asynchronously invoked from: %@", self.previousThreadBacktrace];
	}

	return str;
}

@end
