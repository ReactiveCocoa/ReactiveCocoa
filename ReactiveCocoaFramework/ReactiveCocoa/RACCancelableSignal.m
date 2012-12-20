//
//  RACCancelableSignal.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCancelableSignal.h"
#import "RACSignal+Private.h"
#import "RACConnectableSignal+Private.h"
#import "RACReplaySubject.h"

@interface RACCancelableSignal ()
@property (nonatomic, copy) void (^cancelBlock)(void);
@end

@implementation RACCancelableSignal

#pragma mark RACSignal

- (void)tearDown {
	@synchronized(self) {
		if(self.cancelBlock != NULL) {
			self.cancelBlock();
			self.cancelBlock = NULL;
		}
	}
	
	[super tearDown];
}

#pragma mark API

+ (instancetype)cancelableSignalSourceSignal:(RACSignal *)sourceSignal withBlock:(void (^)(void))block {
	return [self cancelableSignalSourceSignal:sourceSignal subject:[RACReplaySubject subject] withBlock:block];
}

+ (instancetype)cancelableSignalSourceSignal:(RACSignal *)sourceSignal subject:(RACSubject *)subject withBlock:(void (^)(void))block {
	RACCancelableSignal *signal = [self connectableSignalWithSourceSignal:sourceSignal subject:subject];
	[signal connect];
	signal.cancelBlock = block;
	return signal;
}

- (void)cancel {
	[self tearDown];
}

@end
