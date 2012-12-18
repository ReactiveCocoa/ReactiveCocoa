//
//  NSObject+RACBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACBindings.h"
#import "RACSignal+Operations.h"

@implementation NSObject (RACBindings)

- (void)rac_bind:(NSString *)keyPath to:(RACSignal *)signal {
	[signal toProperty:keyPath onObject:self];
}

+ (void)rac_bind:(NSString *)keyPath1 on:(NSObject *)object1 through:(RACSignal *)signalOfProperty2 withKeyPath:(NSString *)keyPath2 on:(NSObject *)object2 through:(RACSignal *)signalOfProperty1 {
	[object1 rac_bind:keyPath1 to:signalOfProperty2];
	[object2 rac_bind:keyPath2 to:signalOfProperty1];
}

@end
