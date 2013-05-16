//
//  NSObject+RACDescription.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACDescription.h"

@implementation NSObject (RACDescription)

- (NSString *)rac_description {
	return [[NSString alloc] initWithFormat:@"<%@: %p>", self.class, self];
}

@end
