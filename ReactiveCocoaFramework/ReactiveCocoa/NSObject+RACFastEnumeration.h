//
//  NSObject+RACFastEnumeration.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/27/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACSubscribable;


@interface NSObject (RACFastEnumeration) // Must conform to NSFastEnumeration

// Sends each object of the enumerable and then completes.
- (RACSubscribable *)toSubscribable;

@end
