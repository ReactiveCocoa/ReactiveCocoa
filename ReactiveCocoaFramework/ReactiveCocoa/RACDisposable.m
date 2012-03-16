//
//  RACDisposable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACDisposable.h"

@interface RACDisposable ()
@property (nonatomic, copy) void (^disposeBlock)(void);
@end


@implementation RACDisposable

- (void)dealloc {
	[self dispose];
}


#pragma mark API

@synthesize disposeBlock;

+ (id)disposableWithBlock:(void (^)(void))block {
	RACDisposable *disposable = [[self alloc] init];
	disposable.disposeBlock = block;
	return disposable;
}

- (void)dispose {
	if(self.disposeBlock != NULL) {
		self.disposeBlock();
		self.disposeBlock = NULL;
	}
}

@end
