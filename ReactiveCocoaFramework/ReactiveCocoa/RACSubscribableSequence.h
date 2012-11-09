//
//  RACSubscribableSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-09.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSequence.h"

@protocol RACSubscribable;

// Private class that adapts a <RACSubscribable> to the RACSequence interface.
@interface RACSubscribableSequence : RACSequence

// Returns a sequence for enumerating over the given subscribable.
+ (RACSequence *)sequenceWithSubscribable:(id<RACSubscribable>)subscribable;

@end
