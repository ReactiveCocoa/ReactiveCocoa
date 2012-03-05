//
//  NSObject+RACPropertyObserving.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RACKVO(property) ((void)(NO && ((void)property, NO)), @#property)
#define RACObservableSequenceForProperty(property) ((void)(NO && ((void)property, NO)), [self observableSequenceForKeyPath:@#property])
#define RACObservableValueForProperty(property) ((void)(NO && ((void)property, NO)), [self observableValueForKeyPath:@#property])

@class RACObservableSequence;
@class RACObservableValue;


@interface NSObject (RACPropertyObserving)

- (RACObservableSequence *)observableSequenceForKeyPath:(NSString *)keyPath;
- (RACObservableValue *)observableValueForKeyPath:(NSString *)keyPath;

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;
- (void)bind:(NSString *)binding toObservable:(RACObservableValue *)observable;

@end
