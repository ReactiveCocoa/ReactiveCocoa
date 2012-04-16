//
//  RACConnectableSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSubscribable.h"
#import "RACConnectableSubscribable+Private.h"
#import "RACSubscribable+Private.h"
#import "RACSubscriber.h"
#import "RACSubject.h"

@interface RACConnectableSubscribable ()
@property (nonatomic, strong) id<RACSubscribable> sourceSubscribable;
@property (nonatomic, strong) RACSubject *subject;
@end


@implementation RACConnectableSubscribable


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.subject subscribe:subscriber];
}


#pragma mark API

@synthesize sourceSubscribable;
@synthesize subject;

+ (RACConnectableSubscribable *)connectableSubscribableWithSourceSubscribable:(id<RACSubscribable>)source subject:(RACSubject *)subject {
	RACConnectableSubscribable *subscribable = [[self alloc] init];
	subscribable.sourceSubscribable = source;
	subscribable.subject = subject;
	return subscribable;
}

- (RACDisposable *)connect {
	return [self.sourceSubscribable subscribe:self.subject];
}

@end
