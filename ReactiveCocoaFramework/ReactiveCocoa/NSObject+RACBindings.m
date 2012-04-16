//
//  NSObject+RACBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACBindings.h"
#import "RACSubscribable.h"
#import "RACSubscribable+Operations.h"


@implementation NSObject (RACBindings)

- (void)rac_bind:(NSString *)keyPath to:(RACSubscribable *)subscribable {
	[subscribable toProperty:keyPath onObject:self];
}

+ (void)rac_bind:(NSString *)keyPath1 on:(NSObject *)object1 through:(RACSubscribable *)subscribableOfProperty2 withKeyPath:(NSString *)keyPath2 on:(NSObject *)object2 through:(RACSubscribable *)subscribableOfProperty1 {
	[object1 rac_bind:keyPath1 to:subscribableOfProperty2];
	[object2 rac_bind:keyPath2 to:subscribableOfProperty1];
}

@end
