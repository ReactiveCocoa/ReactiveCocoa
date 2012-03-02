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

@class RACObservableSequence;


@interface NSObject (RACPropertyObserving)

- (RACObservableSequence *)observableSequenceForKeyPath:(NSString *)keyPath;

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;

@end
