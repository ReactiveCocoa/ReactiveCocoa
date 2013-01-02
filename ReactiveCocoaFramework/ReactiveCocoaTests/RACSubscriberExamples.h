//
//  RACSubscriberExamples.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-27.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for implementors of <RACSubscriber>. This
// example should be passed the following arguments:
//
// getSubscriber  - A block of type `id<RACSubscriber> (^)(void)`, which
//                  should return a <RACSubscriber>.
// valuesReceived - A block which returns an NSArray of the values received so
//                  far.
// errorReceived  - A block which returns any NSError received so far.
// success        - A block which returns a BOOL indicating whether the
//                  subscriber is successful so far.
extern NSString * const RACSubscriberExamples;
