//
//  RACBacktrace.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-20.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#ifdef DEBUG

// Preserves backtraces across asynchronous calls.
@interface RACBacktrace : NSObject

// The backtrace from any previous thread.
@property (nonatomic, strong, readonly) RACBacktrace *previousThreadBacktrace;

// The call stack of this backtrace's thread.
@property (nonatomic, copy, readonly) NSArray *callStackSymbols;

// Captures the current thread's backtrace, appending it to any backtrace from
// a previous thread.
+ (instancetype)backtrace;

// Same as +backtrace, but omits the specified number of frames at the
// top of the stack (in addition to this method itself).
+ (instancetype)backtraceIgnoringFrames:(NSUInteger)ignoreCount;

@end

#endif
