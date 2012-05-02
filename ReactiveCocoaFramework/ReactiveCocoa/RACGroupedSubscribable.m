//
//  RACGroupedSubscribable.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACGroupedSubscribable.h"

@interface RACGroupedSubscribable ()
@property (nonatomic, copy) id<NSCopying> key;
@end


@implementation RACGroupedSubscribable


#pragma mark API

@synthesize key;

+ (id)subscribableWithKey:(id<NSCopying>)key {
	RACGroupedSubscribable *subject = [self subject];
	subject.key = key;
	return subject;
}

@end
