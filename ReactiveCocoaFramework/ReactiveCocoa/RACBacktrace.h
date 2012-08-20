//
//  RACBacktrace.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-20.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// Preserves backtraces across asynchronous calls.
@interface RACBacktrace : NSObject
@property (nonatomic, strong) RACBacktrace *previousThreadBacktrace;
@property (nonatomic, copy) NSArray *callStackSymbols;
@end
