//
//  RACSubscriptionScheduler.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACScheduler.h"

/// A private scheduler used only for subscriptions. See the private
/// +[RACScheduler subscriptionScheduler] method for more information.
@interface RACSubscriptionScheduler : RACScheduler
@end
