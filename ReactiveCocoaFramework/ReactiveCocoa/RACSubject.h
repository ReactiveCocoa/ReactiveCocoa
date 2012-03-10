//
//  RACSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACValue.h"


@interface RACSubject : RACValue

// Send the `next` event to all our observers with the given value.
//
// value - the value to send to our observers. Can be nil.
- (void)sendNext:(id)value;

// Send the `completed` event to all our observers.
- (void)sendCompleted;

// Send the `error` event to all our observers with the given error.
//
// error - the error to send to our observers. Can be nil, though that's highly discouraged.
- (void)sendError:(NSError *)error;

@end
