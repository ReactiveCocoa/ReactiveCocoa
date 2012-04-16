//
//  RACConnectableSubscribable_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/11/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACConnectableSubscribable.h"

@class RACSubject;


@interface RACConnectableSubscribable ()

+ (RACConnectableSubscribable *)connectableSubscribableWithSourceSubscribable:(id<RACSubscribable>)source subject:(RACSubject *)subject;

@end
