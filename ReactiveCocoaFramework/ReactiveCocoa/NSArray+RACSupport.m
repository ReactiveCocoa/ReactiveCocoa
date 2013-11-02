//
//  NSArray+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSArray+RACSupport.h"
#import "RACArraySequence.h"

@implementation NSArray (RACSupport)
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSArray (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	return [RACArraySequence sequenceWithArray:self offset:0];
}

@end

#pragma clang diagnostic pop
