//
//  RACIndexSetSequence.h
//  ReactiveCocoa
//
//  Created by Sergey Gavrilyuk on 12/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSequence.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"

@interface RACIndexSetSequence : RACSequence

+ (instancetype)sequenceWithIndexSet:(NSIndexSet *)indexSet;

@end

#pragma clang diagnostic pop
