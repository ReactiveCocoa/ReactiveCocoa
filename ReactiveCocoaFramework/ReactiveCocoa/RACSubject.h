//
//  RACSubject.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/9/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"
#import "RACSubscriber.h"


// A subject can be thought of as a subscribable that you can manually control by sending next, completed, and error.
@interface RACSubject : RACSubscribable <RACSubscriber>

// Returns a new subject.
+ (id)subject;

@end
