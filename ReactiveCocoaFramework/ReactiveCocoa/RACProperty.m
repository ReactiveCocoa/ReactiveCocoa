//
//  RACProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
#import "RACDisposable.h"

@implementation RACProperty

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendError:(NSError *)error {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendCompleted {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

#pragma mark API

- (RACBinding *)binding {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
	return nil;
}

@end

@implementation RACBinding

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendError:(NSError *)error {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)sendCompleted {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	NSAssert(NO, @"%s must be overridden by subclasses", __func__);
}

#pragma mark API

- (RACDisposable *)bindTo:(RACBinding *)binding {
	RACDisposable *selfDisposable = [self subscribe:binding];
	RACDisposable *bindingDisposable = [binding subscribe:self];
	return [RACDisposable disposableWithBlock:^{
		[selfDisposable dispose];
		[bindingDisposable dispose];
	}];
	
}

@end
