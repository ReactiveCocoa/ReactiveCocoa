//
//  RACReplaySubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"


// A replay subject saves the values it is sent, up to its defined capacity, and resends those to new subscribers.
@interface RACReplaySubject : RACSubject

// Creates a new replay subject with the given capacity. A capacity of 0 means values are never trimmed.
+ (id)replaySubjectWithCapacity:(NSUInteger)capacity;

@end
