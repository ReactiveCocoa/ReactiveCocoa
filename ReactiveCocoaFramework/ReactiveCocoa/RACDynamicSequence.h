//
//  RACDynamicSequence.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "RACSequence.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RACDynamicSequence : RACSequence

+ (RACSequence *)sequenceWithLazyDependency:(id (^)(void))dependencyBlock headBlock:(id (^)(id dependency))headBlock tailBlock:(RACSequence *(^)(id dependency))tailBlock;

@end

#pragma clang diagnostic pop
