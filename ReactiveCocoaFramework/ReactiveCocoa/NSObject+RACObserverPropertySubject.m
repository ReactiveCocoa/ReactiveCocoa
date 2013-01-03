//
//  NSObject+RACObserverPropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACObserverPropertySubject.h"
#import "RACObserverPropertySubject.h"

@implementation NSObject (RACObserverPropertySubject)

- (RACObserverPropertySubject *)rac_propertyForKeyPath:(NSString *)keyPath {
	return [RACObserverPropertySubject propertyWithTarget:self keyPath:keyPath];
}

@end
