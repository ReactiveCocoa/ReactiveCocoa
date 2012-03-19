//
//  RACObservable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACDisposable;
@protocol RACObserver;

@protocol RACObservable <NSObject>
// Subscribes observer to changes on the receiver. The receiver defines which events it actually sends and in what situations the events are sent.
- (RACDisposable *)subscribe:(id<RACObserver>)observer;
@end


@interface RACObservable : NSObject <RACObservable>

+ (id)createObservable:(RACDisposable * (^)(id<RACObserver> observer))didSubscribe;
+ (id)return:(id)value;
+ (id)error:(NSError *)error;
+ (id)empty;
+ (id)never;

@end
