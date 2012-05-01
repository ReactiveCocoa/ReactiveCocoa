//
//  RACAsyncSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/14/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubject.h"


// An async subject saves the most recent object sent and waits to send it until
// the subject completes. If the subject gets a new subscriber after it has been
// completed, it sends that last value and then completes again.
//
// This lets us avoid race conditions when dealing with asynchronous operations.
// If async operation completes before our subscription occurs, the async
// subject will simply replay that result and completion for us.
@interface RACAsyncSubject : RACSubject

@end
