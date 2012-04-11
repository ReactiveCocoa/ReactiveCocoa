//
//  RACSubscribable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;
@protocol RACSubscriber;

@protocol RACSubscribable <NSObject>
// Subscribes observer to changes on the receiver. The receiver defines which events it actually sends and in what situations the events are sent.
- (RACDisposable *)subscribe:(id<RACSubscriber>)observer;
@end


@interface RACSubscribable : NSObject <RACSubscribable>

+ (id)createSubscribable:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe;
+ (id)return:(id)value;
+ (id)error:(NSError *)error;
+ (id)empty;
+ (id)never;

+ (id)start:(id (^)(void))block;

@end
