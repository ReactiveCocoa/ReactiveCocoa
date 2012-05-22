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
#import "RACSubject.h"

@interface RACCancelableSubscribable ()
@property (nonatomic, copy) void (^cancelBlock)(void);
@end


@implementation RACCancelableSubscribable


#pragma mark RACSubscribable

- (void)tearDown {
	if(self.cancelBlock != NULL) {
		self.cancelBlock();
		self.cancelBlock = NULL;
	}
	
	[super tearDown];
}


#pragma mark API

@synthesize cancelBlock;

+ (RACCancelableSubscribable *)cancelableSubscribableSourceSubscribable:(id<RACSubscribable>)sourceSubscribable withBlock:(void (^)(void))block {
	RACCancelableSubscribable *subscribable = [self connectableSubscribableWithSourceSubscribable:sourceSubscribable subject:[RACSubject subject]];
	subscribable.cancelBlock = block;
	return subscribable;
}

- (void)cancel {
	[self tearDown];
}

@end
