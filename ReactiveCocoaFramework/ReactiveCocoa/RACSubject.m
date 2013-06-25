//
//  RACSubject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"
#import "RACSignal+Private.h"
#import "RACCompoundDisposable.h"

@interface RACSubject ()

@property (nonatomic, strong, readonly) RACCompoundDisposable *disposable;

@end

@implementation RACSubject

#pragma mark Lifecycle

+ (instancetype)subject {
	return [[self alloc] init];
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	_disposable = [RACCompoundDisposable compoundDisposable];
	
	return self;
}

- (void)dealloc {
	[self.disposable dispose];
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:value];
	}];
}

- (void)sendError:(NSError *)error {
	[self.disposable dispose];
	
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendError:error];
	}];
}

- (void)sendCompleted {
	[self.disposable dispose];
	
	[self performBlockOnEachSubscriber:^(id<RACSubscriber> subscriber) {
		[subscriber sendCompleted];
	}];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)d {
	if (d != nil) [self.disposable addDisposable:d];
}

@end
