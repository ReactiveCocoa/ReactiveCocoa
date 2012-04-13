//
//  RACConnectableSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACConnectableSubscribable.h"
#import "RACConnectableSubscribable+Private.h"
#import "RACSubscribable+Private.h"
#import "RACSubscriber.h"

@interface RACConnectableSubscribable ()
@property (nonatomic, strong) id<RACSubscribable> sourceSubscribable;
@end


@implementation RACConnectableSubscribable


#pragma mark API

@synthesize sourceSubscribable;

+ (RACConnectableSubscribable *)connectableSubscribableWithSourceSubscribable:(id<RACSubscribable>)source {
	RACConnectableSubscribable *subscribable = [[self alloc] init];
	subscribable.sourceSubscribable = source;
	return subscribable;
}

- (RACDisposable *)connect {
	return [self.sourceSubscribable subscribe:[RACSubscriber subscriberWithNext:^(id x) {
		[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
			[subscriber sendNext:x];
		}];
	} error:^(NSError *error) {
		[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
			[subscriber sendError:error];
		}];
	} completed:^{
		[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
			[subscriber sendCompleted];
		}];
	}]];
}

@end
