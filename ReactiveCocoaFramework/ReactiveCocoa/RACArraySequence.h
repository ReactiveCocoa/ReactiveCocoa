//
//  RACArraySequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RACArraySequence : RACSequence

+ (instancetype)sequenceWithArray:(NSArray *)array offset:(NSUInteger)offset;

@end

#pragma clang diagnostic pop
