//
//  RACBacktrace.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-20.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// Preserves backtraces across asynchronous calls.
//
// On OS X, you can enable the automatic capturing of asynchronous backtraces
// (in Debug builds) by setting the `DYLD_INSERT_LIBRARIES` environment variable
// to `@executable_path/../Frameworks/ReactiveCocoa.framework/ReactiveCocoa` in
// your scheme's Run action settings.
//
// On iOS, capturing of asynchronous backtraces is performed automatically in
// Debug builds. This capability is enabled by Fishhook, see
// https://github.com/facebook/fishhook for details.
//
// Once backtraces are being captured, you can `po [RACBacktrace backtrace]` in
// the debugger to print them out at any time. You can even set up an alias in
// ~/.lldbinit to do so:
//
//    command alias racbt po [RACBacktrace backtrace]
// 
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
