//
//  RACBacktrace+Private.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-07-25.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

// RACBacktrace is only enabled for `DEBUG` builds, and in the case of iOS, only
// on the simulator, not on device.
#if defined(DEBUG) && (TARGET_IPHONE_SIMULATOR || !TARGET_OS_IPHONE)

extern void rac_dispatch_async(dispatch_queue_t queue, dispatch_block_t block);
extern void rac_dispatch_barrier_async(dispatch_queue_t queue, dispatch_block_t block);
extern void rac_dispatch_after(dispatch_time_t time, dispatch_queue_t queue, dispatch_block_t block);
extern void rac_dispatch_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function);
extern void rac_dispatch_barrier_async_f(dispatch_queue_t queue, void *context, dispatch_function_t function);
extern void rac_dispatch_after_f(dispatch_time_t time, dispatch_queue_t queue, void *context, dispatch_function_t function);

#define dispatch_async rac_dispatch_async
#define dispatch_barrier_async rac_dispatch_barrier_async
#define dispatch_after rac_dispatch_after
#define dispatch_async_f rac_dispatch_async_f
#define dispatch_barrier_async_f rac_dispatch_barrier_async_f
#define dispatch_after_f rac_dispatch_after_f

#endif
