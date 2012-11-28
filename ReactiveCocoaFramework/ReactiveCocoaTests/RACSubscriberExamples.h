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
// getSubscriber - A block of type `id<RACSubscriber> (^)(void)`, which
//                 should return a <RACSubscriber>.
// verifyNexts   - A block of type `void (^)(NSSet *)`, which should verify
//                 that the subscriber received all of the values in the set
//                 (regardless of order).
extern NSString * const RACSubscriberExamples;
