//
//  NSObject+RACObservablePropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACObservablePropertySubject.h"
#import "RACObservablePropertySubject.h"

@implementation NSObject (RACObservablePropertySubject)

- (RACObservablePropertySubject *)rac_propertyForKeyPath:(NSString *)keyPath {
	return [RACObservablePropertySubject propertyWithTarget:self keyPath:keyPath];
}

@end
