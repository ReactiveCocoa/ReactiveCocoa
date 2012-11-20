//
//  NSObject+RACBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSignal;


@interface NSObject (RACBindings)

// Bind the value of `keyPath` to the latest value of `subscribable`.
- (void)rac_bind:(NSString *)keyPath to:(RACSignal *)subscribable;

// Creates a binding for each object key path to the given subscribables. This
// can effectively be used to create 2-way bindings.
+ (void)rac_bind:(NSString *)keyPath1 on:(NSObject *)object1 through:(RACSignal *)subscribableOfProperty2 withKeyPath:(NSString *)keyPath2 on:(NSObject *)object2 through:(RACSignal *)subscribableOfProperty1;

@end
