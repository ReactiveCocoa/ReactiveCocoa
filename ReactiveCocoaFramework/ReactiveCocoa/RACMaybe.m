//
//  RACMaybe.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACMaybe.h"
#import "RACTuple.h"

@interface RACMaybe ()
@property (nonatomic, strong) id object;
@property (nonatomic, strong) NSError *error;
@end


@implementation RACMaybe


#pragma mark API

@synthesize object;
@synthesize error;

+ (id)maybeWithObject:(id)object {
	RACMaybe *maybe = [[self alloc] init];
	maybe.object = object ? : [RACTupleNil tupleNil];
	return maybe;
}

+ (id)maybeWithError:(NSError *)error {
	RACMaybe *maybe = [[self alloc] init];
	maybe.error = error;
	return maybe;
}

- (BOOL)hasObject {
	return object != nil;
}

- (BOOL)hasError {
	return self.error != nil;
}

- (id)object {
	return [object isKindOfClass:[RACTupleNil class]] ? nil : object;
}

@end
