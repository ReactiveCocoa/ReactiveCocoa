//
//  RACTupleSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-05-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSequence.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RACTupleSequence : RACSequence

+ (instancetype)sequenceWithTupleBackingArray:(NSArray *)backingArray offset:(NSUInteger)offset;

@end

#pragma clang diagnostic pop
