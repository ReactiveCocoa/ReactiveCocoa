//
//  NSIndexSet+RACSupport.h
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/17/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACDeprecated.h"

@class RACSequence;
@class RACSignal;

@interface NSIndexSet (RACSupport)

/// A signal that will send all of the indexes (as `NSNumber`s) in the receiver.
///
/// Mutating the receiver will not affect the signal after it's been created.
@property (nonatomic, strong, readonly) RACSignal *rac_signal;

@end

@interface NSIndexSet (RACSupportDeprecated)

@property (nonatomic, copy, readonly) RACSequence *rac_sequence;

@end
