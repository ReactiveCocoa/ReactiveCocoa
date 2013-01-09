//
//  RACScopedDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScopedDisposable.h"

@implementation RACScopedDisposable

#pragma mark Lifecycle

+ (instancetype)scopedDisposableWithDisposable:(RACDisposable *)disposable {
	return [self disposableWithBlock:^{
		[disposable dispose];
	}];
}

- (void)dealloc {
	[self dispose];
}

#pragma mark RACDisposable

- (RACScopedDisposable *)asScopedDisposable {
	// totally already are
	return self;
}

@end
