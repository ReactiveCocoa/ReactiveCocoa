//
//  RACCancelableSubscribable_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCancelableSubscribable.h"


@interface RACCancelableSubscribable ()

// Defaults to using a RACReplaySubject.
+ (instancetype)cancelableSubscribableSourceSubscribable:(RACSubscribable *)subscribable withBlock:(void (^)(void))block;
+ (instancetype)cancelableSubscribableSourceSubscribable:(RACSubscribable *)sourceSubscribable subject:(RACSubject *)subject withBlock:(void (^)(void))block;

@end
