//
//  NSIndexSet+RACSequenceAdditions.h
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/17/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RACSequence.h"

@interface NSIndexSet (RACSequenceAdditions)

/// Creates and returns a sequence of indexes corresponding to the receiver.
/// NSUinteger indexes are wrapped into NSNumbers when passing along.
///
/// Mutating the receiver will not affect the sequence after it's been created.
@property (nonatomic, copy, readonly) RACSequence *rac_sequence;
@end
