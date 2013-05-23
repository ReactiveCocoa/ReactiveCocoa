//
//  RACBacktraceOSXSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 23/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBacktrace+Private.h"
#import "RACScheduler.h"

#ifdef DEBUG

static RACBacktrace *previousBacktrace;

static void capturePreviousBacktrace(void *context) {
	previousBacktrace = [RACBacktrace captureBacktrace].previousThreadBacktrace;
}

SpecBegin(RACBacktraceOSX)

__block dispatch_block_t block;

beforeEach(^{
	expect([RACBacktrace captureBacktrace].previousThreadBacktrace).to.beNil();
	previousBacktrace = nil;
	
	block = ^{
		capturePreviousBacktrace(NULL);
	};
});

it(@"should trace across an NSOperationQueue", ^{
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	[queue addOperationWithBlock:block];
	expect(previousBacktrace).willNot.beNil();
});

SpecEnd

#endif
