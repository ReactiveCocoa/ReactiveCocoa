//
//  RACBacktrace.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-16.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <execinfo.h>
#import <pthread.h>
#import "RACBacktrace+Private.h"

#define RAC_BACKTRACE_MAX_CALL_STACK_FRAMES 128

#ifdef DEBUG

// Undefine the private macros that hide the real GCD functions.
#undef dispatch_async
#undef dispatch_barrier_async
#undef dispatch_after
#undef dispatch_async_f
#undef dispatch_barrier_async_f
#undef dispatch_after_f

@interface RACBacktrace () {
	void *_callStackAddresses[RAC_BACKTRACE_MAX_CALL_STACK_FRAMES];
	int _callStackSize;
}

@property (nonatomic, strong, readwrite) RACBacktrace *previousThreadBacktrace;
@end

@interface RACDispatchInfo : NSObject

// The recorded backtrace.
@property (nonatomic, strong, readonly) RACBacktrace *backtrace;

// The information for the original dispatch.
@property (nonatomic, readonly) dispatch_function_t function;
@property (nonatomic, readonly) void *context;
@property (nonatomic, readonly) dispatch_queue_t queue;

- (id)initWithQueue:(dispatch_queue_t)queue function:(dispatch_function_t)function context:(void *)context;

@end

// Function for use with dispatch_async_f and friends, which will save the
// backtrace onto the current queue, then call through to the original dispatch.
static void RACTraceDispatch (void *ptr) {
	// Balance out the retain necessary for async calls.
	RACDispatchInfo *info __attribute__((objc_precise_lifetime)) = CFBridgingRelease(ptr);

	dispatch_queue_set_specific(info.queue, (void *)pthread_self(), (__bridge void *)info.backtrace, NULL);
	info.function(info.context);
	dispatch_queue_set_specific(info.queue, (void *)pthread_self(), NULL, NULL);
}

// Always inline this function, for consistency in backtraces.
__attribute__((always_inline))
static dispatch_block_t RACBacktraceBlock (dispatch_queue_t queue, dispatch_block_t block) {
	RACBacktrace *backtrace = [RACBacktrace captureBacktrace];

	return [^{
		RACBacktrace *backtraceKeptAlive __attribute__((objc_precise_lifetime)) = backtrace;

		dispatch_queue_set_specific(queue, (void *)pthread_self(), (__bridge void *)backtraceKeptAlive, NULL);
		block();
		dispatch_queue_set_specific(queue, (void *)pthread_self(), NULL, NULL);
	} copy];
}

void rac_dispatch_async(dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_async(queue, RACBacktraceBlock(queue, block));
}

void rac_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_barrier_async(queue, RACBacktraceBlock(queue, block));
}

void rac_dispatch_after(dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block) {
	dispatch_after(time, queue, RACBacktraceBlock(queue, block));
}

void rac_dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function) {
	RACDispatchInfo *info = [[RACDispatchInfo alloc] initWithQueue:queue function:function context:context];
	dispatch_async_f(queue, (void *)CFBridgingRetain(info), &RACTraceDispatch);
}

void rac_dispatch_barrier_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function) {
	RACDispatchInfo *info = [[RACDispatchInfo alloc] initWithQueue:queue function:function context:context];
	dispatch_barrier_async_f(queue, (void *)CFBridgingRetain(info), &RACTraceDispatch);
}

void rac_dispatch_after_f(dispatch_time_t time, dispatch_queue_t queue, void *context, dispatch_function_t function) {
	RACDispatchInfo *info = [[RACDispatchInfo alloc] initWithQueue:queue function:function context:context];
	dispatch_after_f(time, queue, (void *)CFBridgingRetain(info), &RACTraceDispatch);
}

// This is what actually performs the injection.
//
// The DYLD_INSERT_LIBRARIES environment variable must include the RAC dynamic
// library in order for this to work.
__attribute__((used)) static struct { const void *replacement; const void *replacee; } interposers[] __attribute__((section("__DATA,__interpose"))) = {
	{ (const void *)&rac_dispatch_async, (const void *)&dispatch_async },
	{ (const void *)&rac_dispatch_barrier_async, (const void *)&dispatch_barrier_async },
	{ (const void *)&rac_dispatch_after, (const void *)&dispatch_after },
	{ (const void *)&rac_dispatch_async_f, (const void *)&dispatch_async_f },
	{ (const void *)&rac_dispatch_barrier_async_f, (const void *)&dispatch_barrier_async_f },
	{ (const void *)&rac_dispatch_after_f, (const void *)&dispatch_after_f },
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

#pragma mark Properties

- (NSArray *)callStackSymbols {
	if (_callStackSize == 0) return @[];

	char **symbols = backtrace_symbols(_callStackAddresses, _callStackSize);
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:(NSUInteger)_callStackSize];

	for (int i = 0; i < _callStackSize; i++) {
		NSString *str = @(symbols[i]);
		[array addObject:str];
	}

	free(symbols);
	return array;
}

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
	@autoreleasepool {
		RACBacktrace *oldBacktrace = (__bridge id)dispatch_get_specific((void *)pthread_self());

		RACBacktrace *newBacktrace = [[RACBacktrace alloc] init];
		newBacktrace.previousThreadBacktrace = oldBacktrace;

		int size = backtrace(newBacktrace->_callStackAddresses, RAC_BACKTRACE_MAX_CALL_STACK_FRAMES);

		// Omit this method plus however many others from the backtrace.
		++ignoreCount;
		if ((NSUInteger)size > ignoreCount) {
			memmove(newBacktrace->_callStackAddresses, newBacktrace->_callStackAddresses + ignoreCount, ((NSUInteger)size - ignoreCount) * sizeof(char *));
			size -= (int)ignoreCount;
		}

		newBacktrace->_callStackSize = size;
		return newBacktrace;
	}
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

@implementation RACDispatchInfo

#pragma mark Lifecycle

- (id)initWithQueue:(dispatch_queue_t)queue function:(dispatch_function_t)function context:(void *)context {
	@autoreleasepool {
		NSCParameterAssert(queue != NULL);
		NSCParameterAssert(function != NULL);

		self = [super init];
		if (self == nil) return nil;

		_backtrace = [RACBacktrace captureBacktraceIgnoringFrames:1];

		dispatch_retain(queue);
		_queue = queue;

		_function = function;
		_context = context;

		return self;
	}
}

- (void)dealloc {
	if (_queue != NULL) {
		dispatch_release(_queue);
		_queue = NULL;
	}
}

@end

#endif
