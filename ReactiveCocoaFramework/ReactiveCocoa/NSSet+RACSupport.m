//
//  NSSet+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSSet+RACSupport.h"
#import "NSArray+RACSupport.h"

@implementation NSSet (RACSupport)

- (RACSequence *)rac_sequence {
	// TODO: First class support for set sequences.
	return self.allObjects.rac_sequence;
}

@end
