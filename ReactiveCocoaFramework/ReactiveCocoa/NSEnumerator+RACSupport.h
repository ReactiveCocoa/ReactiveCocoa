//
//  NSEnumerator+RACSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 07/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACSequence;

@interface NSEnumerator (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Enumerate -allObjects instead");

@end
