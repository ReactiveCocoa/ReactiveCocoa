//
//  RACObservableArray_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSequence.h"


@interface RACSequence ()

@property (nonatomic, readonly) NSUInteger count;

- (id)initWithCapacity:(NSUInteger)cap;

- (void)addObjectAndNilsAreOK:(id)object;
- (void)removeFirstObject;

- (void)sendNextToAllObservers:(id)value;
- (void)sendCompletedToAllObservers;
- (void)sendErrorToAllObservers:(NSError *)error;

@end
