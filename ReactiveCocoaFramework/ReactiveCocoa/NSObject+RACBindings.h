//
//  NSObject+RACBindings.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubscribable;


@interface NSObject (RACBindings)

- (void)rac_bind:(NSString *)keyPath to:(RACSubscribable *)subscribable;

+ (void)rac_bind:(NSString *)keyPath1 on:(NSObject *)object1 through:(RACSubscribable *)subscribableOfProperty2 withKeyPath:(NSString *)keyPath2 on:(NSObject *)object2 through:(RACSubscribable *)subscribableOfProperty1;

@end
