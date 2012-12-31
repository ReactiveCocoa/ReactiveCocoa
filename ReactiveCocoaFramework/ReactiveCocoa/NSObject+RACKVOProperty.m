//
//  NSObject+RACKVOProperty.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACKVOProperty.h"
#import "RACKVOProperty.h"

@implementation NSObject (RACKVOProperty)

- (RACKVOProperty *)rac_propertyForKeyPath:(NSString *)keyPath {
	return [RACKVOProperty propertyWithTarget:self keyPath:keyPath];
}

@end
