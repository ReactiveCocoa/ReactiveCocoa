//
//  NSObject+RACBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACBindings.h"
#import "RACSignal.h"


@implementation NSObject (RACBindings)

- (void)rac_bind:(NSString *)keyPath to:(RACSignal *)subscribable {
	[subscribable toProperty:keyPath onObject:self];
}

+ (void)rac_bind:(NSString *)keyPath1 on:(NSObject *)object1 through:(RACSignal *)subscribableOfProperty2 withKeyPath:(NSString *)keyPath2 on:(NSObject *)object2 through:(RACSignal *)subscribableOfProperty1 {
	[object1 rac_bind:keyPath1 to:subscribableOfProperty2];
	[object2 rac_bind:keyPath2 to:subscribableOfProperty1];
}

@end
