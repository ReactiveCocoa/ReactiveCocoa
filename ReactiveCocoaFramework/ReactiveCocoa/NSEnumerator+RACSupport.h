//
//  NSEnumerator+RACSupport.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 07/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACPromise;
@class RACSequence;

@interface NSEnumerator (RACSupport)

/// A promise that, when executed, will synchronously send the enumerator's
/// values.
///
/// The enumerator will be exhausted after the promise has executed.
///
/// It is not safe to mutate the underlying collection while the promise is
/// executing.
@property (nonatomic, strong, readonly) RACPromise *rac_promise;

@end

@interface NSEnumerator (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence RACDeprecated("Use -rac_signal instead");

@end
