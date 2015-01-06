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

- (RACSequence *)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence {
	return passthroughSequence ?: self;
}

#pragma mark NSCoding

- (Class)classForCoder {
	// Empty sequences should be encoded as themselves, not array sequences.
	return self.class;
}

- (id)initWithCoder:(NSCoder *)coder {
	// Return the singleton.
	return self.class.empty;
}

- (void)encodeWithCoder:(NSCoder *)coder {
}

#pragma mark NSObject

- (NSString *)description {
	return [NSString stringWithFormat:@"<%@: %p>{ name = %@ }", self.class, self, self.name];
}

- (NSUInteger)hash {
	// This hash isn't ideal, but it's better than -[RACSequence hash], which
	// would just be zero because we have no head.
	return (NSUInteger)(__bridge void *)self;
}

- (BOOL)isEqual:(RACSequence *)seq {
	return (self == seq);
}

@end
