//
//  RACAction.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-31.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACAction.h"
#import "RACAction+Private.h"

@implementation RACAction

#pragma mark Lifecycle

- (id)init {
	[self doesNotRecognizeSelector:_cmd];
	return nil;
}

@end
