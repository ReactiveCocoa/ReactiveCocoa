//
//  RACEmptySequence.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACEmptySequence.h"

@implementation RACEmptySequence

#pragma mark Lifecycle

+ (instancetype)empty {
	static id singleton;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		singleton = [[self alloc] init];
	});

	return singleton;
}

#pragma mark RACSequence

- (id)head {
	return nil;
}

- (RACSequence *)tail {
	return nil;
}

#pragma mark NSObject

- (NSUInteger)hash {
	// This hash isn't ideal, but it's better than -[RACSequence hash], which
	// would just be zero because we have no head.
	return (NSUInteger)(__bridge void *)self;
}

- (BOOL)isEqual:(RACSequence *)seq {
	return (self == seq);
}

@end
