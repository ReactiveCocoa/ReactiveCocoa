//
//  RACGroupedSignal.m
//  ReactiveObjC
//
//  Created by Josh Abernathy on 5/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACGroupedSignal.h"

@interface RACGroupedSignal ()
@property (nonatomic, copy) id<NSCopying> key;
@end

@implementation RACGroupedSignal

#pragma mark API

+ (instancetype)signalWithKey:(id<NSCopying>)key {
	RACGroupedSignal *subject = [self subject];
	subject.key = key;
	return subject;
}

@end
