//
//  RACScopedDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScopedDisposable.h"

@interface RACScopedDisposable ()
@property (nonatomic, strong) RACDisposable *disposable;
@end


@implementation RACScopedDisposable

- (void)dealloc {
	[self dispose];
	[self.disposable dispose];
}


#pragma mark RACDisposable

- (RACScopedDisposable *)asScopedDisposable {
	// totally already are
	return self;
}


#pragma mark API

@synthesize disposable;

+ (id)scopedDisposableWithDisposable:(RACDisposable *)disposable {
	RACScopedDisposable *scopedDisposable = [[self alloc] init];
	scopedDisposable.disposable = disposable;
	return scopedDisposable;
}

@end
