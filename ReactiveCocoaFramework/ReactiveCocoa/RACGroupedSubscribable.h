//
//  RACGroupedSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"


// A grouped subscribable is used by -[RACSubscribable groupBy:transform:].
@interface RACGroupedSubscribable : RACSubject

// The key shared by the group.
@property (nonatomic, readonly, copy) id<NSCopying> key;

+ (id)subscribableWithKey:(id<NSCopying>)key;

@end
