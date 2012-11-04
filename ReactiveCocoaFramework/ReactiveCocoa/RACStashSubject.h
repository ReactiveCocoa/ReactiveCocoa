//
//  RACStashSubject.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 11/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"


// A stash subject resends the `next`s it receives to it's subscribers if it has
// any, or to the first subscriber that subscribes to it if not. It will also
// replay an error or completion to all new subscribers.
@interface RACStashSubject : RACSubject

// Creates a new stash subject. If `latestValueOnly` is true only the latest
// value is stashed when the subject has no subscribers, otherwise all values
// are stashed.
+ (instancetype)stashSubjectWithLatestValueOnly:(BOOL)latestValueOnly;

@end
