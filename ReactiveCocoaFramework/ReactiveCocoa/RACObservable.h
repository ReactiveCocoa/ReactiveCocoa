//
//  RACObservable.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/1/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RACObserver;


@protocol RACObservable <NSObject>

// Subscribes observer to changes on the receiver. The receiver defines which events it actually sends and in what situations the events are sent.
- (id)subscribe:(RACObserver *)observer;

// Unsubscribes the observer.
- (void)unsubscribe:(RACObserver *)observer;

@end
