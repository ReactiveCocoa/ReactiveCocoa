//
//  RACStringSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"

/// Private class that adapts a string to the RACSequence interface.
@interface RACStringSequence : RACSequence

/// Returns a sequence for enumerating over the given string, starting from the
/// given character offset. The string will be copied to prevent mutation.
+ (RACSequence *)sequenceWithString:(NSString *)string offset:(NSUInteger)offset;

@end
