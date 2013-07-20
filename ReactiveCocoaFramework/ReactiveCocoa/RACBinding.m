//
//  RACBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding+Private.h"
#import "EXTScope.h"
#import "RACDisposable.h"
#import "RACSubscriber+Private.h"
#import "RACTuple.h"

@implementation RACBinding

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.signal subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.subscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.subscriber sendError:error];
}

- (void)sendCompleted {
	[self.subscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.subscriber didSubscribeWithDisposable:disposable];
}

@end

@implementation RACBinding (Deprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

- (RACDisposable *)bindTo:(RACBinding *)binding {
	RACDisposable *bindingDisposable = [binding subscribe:self];
	RACDisposable *selfDisposable = [[self skip:1] subscribe:binding];
	return [RACDisposable disposableWithBlock:^{
		[bindingDisposable dispose];
		[selfDisposable dispose];
	}];
}

#pragma clang diagnostic pop

@end
