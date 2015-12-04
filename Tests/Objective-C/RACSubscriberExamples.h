//
//  RACSubscriberExamples.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-11-27.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

// The name of the shared examples for implementors of <RACSubscriber>.
extern NSString * const RACSubscriberExamples;

// id<RACSubscriber>
extern NSString * const RACSubscriberExampleSubscriber;

// A block which returns an NSArray of the values received so far.
extern NSString * const RACSubscriberExampleValuesReceivedBlock;

// A block which returns any NSError received so far.
extern NSString * const RACSubscriberExampleErrorReceivedBlock;

// A block which returns a BOOL indicating whether the subscriber is successful
// so far.
extern NSString * const RACSubscriberExampleSuccessBlock;
