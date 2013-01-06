//
//  RACBacktrace+Private.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-12-24.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/RACBacktrace.h>

// When this header is imported in RAC sources, any uses of GCD dispatches (in
// Debug builds) will automatically use the backtrace-logging overrides instead.
#ifdef DEBUG

void rac_dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
void rac_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block);
void rac_dispatch_after(dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block);
void rac_dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function);
void rac_dispatch_barrier_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function);
void rac_dispatch_after_f(dispatch_time_t time, dispatch_queue_t queue, void *context, dispatch_function_t function);

#define dispatch_async(...) \
	rac_dispatch_async(__VA_ARGS__)

#define dispatch_barrier_async(...) \
	rac_dispatch_barrier_async(__VA_ARGS__)

#define dispatch_after(...) \
	rac_dispatch_after(__VA_ARGS__)

#define dispatch_async_f(...) \
	rac_dispatch_async_f(__VA_ARGS__)

#define dispatch_barrier_async_f(...) \
	rac_dispatch_barrier_async_f(__VA_ARGS__)

#define dispatch_after_f(...) \
	rac_dispatch_after_f(__VA_ARGS__)

#endif
