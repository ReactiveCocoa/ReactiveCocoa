//
//  RACGroupedSignal.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACDeprecated.h"
#import "RACSubject.h"

RACDeprecated("Use a plain RACSignal and -map: instead")
@interface RACGroupedSignal : RACSubject

@property (nonatomic, readonly, copy) id<NSCopying> key;

+ (instancetype)signalWithKey:(id<NSCopying>)key;

@end
