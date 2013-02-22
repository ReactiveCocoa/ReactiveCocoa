//
//  RACProxy.m
//  ReactiveCocoa
//
//  Created by Avi Itskovich on 2/21/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACProxy.h"

@interface RACProxy()

@property (nonatomic, retain) RACSequence *sequence;

- (id)initWithSequence:(RACSequence *)sequence;

@end

@implementation RACProxy

+ (id)return:(id (^)(void))block {
	return [[RACProxy alloc] initWithSequence:[RACSequence sequenceWithHeadBlock:block tailBlock:nil]];
}

- (id)initWithSequence:(RACSequence *)sequence {
	self = [super init];
	if (self) {
		_sequence = sequence;
	}
	return self;
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
	return self.sequence.head;
}

@end
