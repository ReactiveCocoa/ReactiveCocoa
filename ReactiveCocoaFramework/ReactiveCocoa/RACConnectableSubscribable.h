//
//  RACConnectableSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSubscribable.h"


@interface RACConnectableSubscribable : RACSubscribable

// Connect to the underlying subscribable.
- (RACDisposable *)connect;

@end
