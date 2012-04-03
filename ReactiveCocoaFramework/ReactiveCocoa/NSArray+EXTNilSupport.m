//
//  NSArray+EXTNilSupport.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSArray+EXTNilSupport.h"
#import "EXTNil.h"


@implementation NSArray (EXTNilSupport)

- (id)rac_objectOrNilAtIndex:(NSUInteger)index {
	id object = [self objectAtIndex:index];
	return [object isKindOfClass:[EXTNil class]] ? nil : object;
}

@end
