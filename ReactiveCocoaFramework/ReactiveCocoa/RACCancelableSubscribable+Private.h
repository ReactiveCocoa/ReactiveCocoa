//
//  RACCancelableSubscribable_Private.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 5/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCancelableSubscribable.h"


@interface RACCancelableSubscribable ()

+ (RACCancelableSubscribable *)cancelableSubscribableSourceSubscribable:(id<RACSubscribable>)subscribable withBlock:(void (^)(void))block;

@end
