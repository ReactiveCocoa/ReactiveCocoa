//
//  RACCancelableSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCancelableSubscribable.h"
#import "RACSubscribable+Private.h"
#import "RACConnectableSubscribable+Private.h"
#import "RACReplaySubject.h"

@interface RACCancelableSubscribable ()
@property (nonatomic, copy) void (^cancelBlock)(void);
@end


@implementation RACCancelableSubscribable


#pragma mark RACSubscribable

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

@synthesize cancelBlock;

+ (instancetype)cancelableSubscribableSourceSubscribable:(id<RACSubscribable>)sourceSubscribable withBlock:(void (^)(void))block {
	return [self cancelableSubscribableSourceSubscribable:sourceSubscribable subject:[RACReplaySubject subject] withBlock:block];
}

+ (instancetype)cancelableSubscribableSourceSubscribable:(id<RACSubscribable>)sourceSubscribable subject:(RACSubject *)subject withBlock:(void (^)(void))block {
	RACCancelableSubscribable *subscribable = [self connectableSubscribableWithSourceSubscribable:sourceSubscribable subject:subject];
	[subscribable connect];
	subscribable.cancelBlock = block;
	return subscribable;
}

- (void)cancel {
	[self tearDown];
}

@end
