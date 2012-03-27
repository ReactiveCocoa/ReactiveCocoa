//
//  NSObject+RACFastEnumeration.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/27/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RACSubscribable;


@interface NSObject (RACFastEnumeration) // Must conform to NSFastEnumeration

- (id<RACSubscribable>)toSubscribable;

@end
