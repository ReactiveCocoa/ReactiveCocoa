//
//  RACGroupedSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"


@interface RACGroupedSubscribable : RACSubject

@property (nonatomic, readonly, copy) id<NSCopying> key;

+ (id)subscribableWithKey:(id<NSCopying>)key;

@end
