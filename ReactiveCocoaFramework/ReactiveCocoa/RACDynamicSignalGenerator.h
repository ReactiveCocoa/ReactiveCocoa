//
//  RACDynamicSignalGenerator.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalGenerator.h"

@interface RACDynamicSignalGenerator : RACSignalGenerator

+ (instancetype)generatorWithBlock:(RACSignal * (^)(id input))block;

@end
