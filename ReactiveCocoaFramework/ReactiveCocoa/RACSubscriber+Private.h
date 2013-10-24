//
//  RACSubscriber+Private.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSubscriber.h"

/// A simple block-based subscriber.
@interface RACSubscriber : NSObject <RACSubscriber>

/// Creates a new subscriber with the given blocks.
+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed;

/// Attempts to suspend any signals that the receiver is attached to, to prevent
/// them from generating events until -resumeSignals is invoked.
///
/// These methods may be nested.
- (void)suspendSignals;

/// Resumes signals that the receiver is attached to.
///
/// Does nothing if there was no previous invocation of -suspendSignals.
- (void)resumeSignals;

@end
