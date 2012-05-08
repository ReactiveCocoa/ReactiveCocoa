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
#import "RACSubscribable+Operations.h"

@interface RACConnectableSubscribable ()
@property (nonatomic, strong) id<RACSubscribable> sourceSubscribable;
@property (nonatomic, strong) RACSubject *subject;
@property (strong) RACDisposable *disposable;
@end


@implementation RACConnectableSubscribable


#pragma mark RACSubscribable

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.subject subscribe:subscriber];
}


#pragma mark API

@synthesize sourceSubscribable;
@synthesize subject;
@synthesize disposable;

+ (RACConnectableSubscribable *)connectableSubscribableWithSourceSubscribable:(id<RACSubscribable>)source subject:(RACSubject *)subject {
	RACConnectableSubscribable *subscribable = [[self alloc] init];
	subscribable.sourceSubscribable = source;
	subscribable.subject = subject;
	return subscribable;
}

- (RACDisposable *)connect {
	if(self.disposable == nil) {
		self.disposable = [self.sourceSubscribable subscribe:self.subject];
	}
	
	return self.disposable;
}

- (RACSubscribable *)autoconnect {
	return [RACSubscribable defer:^{
		[self connect];
		return self;
	}];
}

@end
