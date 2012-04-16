//
//  NSArray+RACExtensions.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSArray+RACExtensions.h"


@implementation NSArray (RACExtensions)

- (NSArray *)rac_select:(id (^)(id object))block {
	NSParameterAssert(block != NULL);
	
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.count];
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		id newObject = block(obj);
		NSAssert(newObject != nil, @"The select block returned nil for %@", obj);
		
		[newArray addObject:newObject];
	}];
	
	return [newArray copy];
}

- (NSArray *)rac_where:(BOOL (^)(id object))block {
	NSParameterAssert(block != NULL);
	
	NSMutableArray *newArray = [NSMutableArray arrayWithCapacity:self.count];
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if(block(obj)) {
			[newArray addObject:obj];
		}
	}];
	
	return [newArray copy];
}

- (BOOL)rac_any:(BOOL (^)(id object))block {
	NSParameterAssert(block != NULL);
	
	__block BOOL foundPassingObject = NO;
	[self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		if(block(obj)) {
			foundPassingObject = YES;
			*stop = YES;
		}
	}];
	
	return foundPassingObject;
}

@end
