//
//  RACObservableArray_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACSequence.h"


@interface RACSequence ()

// The number of objects in the sequence.
@property (nonatomic, readonly) NSUInteger count;

@property (nonatomic, copy) void (^didSubscribe)(RACSequence *sequence, RACObserver *observer);

// Initializes the new sequence with the given capacity.
- (id)initWithCapacity:(NSUInteger)cap;

// Add a new object into the sequence. This will notify observers of this object. 
// Note: unlike `-addObject:`, you may pass nil to this method. Passing nil doesn't actually insert anything into the sequence, but it does notify all the sequence's observers with a nil object.
//
// object - the object to insert into the sequence. Can be nil.
- (void)addObjectAndNilsAreOK:(id)object;

// Removes the first object or does nothing if the sequence has no objects.
- (void)removeFirstObject;

// Send the `next` event to all our observers with the given value.
//
// value - the value to send to our observers. Can be nil.
- (void)sendNextToAllObservers:(id)value;

// Send the `completed` event to all our observers.
- (void)sendCompletedToAllObservers;

// Send the `error` event to all our observers with the given error.
//
// error - the error to send to our observers. Can be nil, though that's highly discouraged.
- (void)sendErrorToAllObservers:(NSError *)error;

@end
