//
//  NSObject+RACPropertyObserving.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RACObservableSequenceForProperty(property) ((void)(NO && ((void)property, NO)), [self observableSequenceForKeyPath:@#property])

@class RACObservableSequence;


@interface NSObject (RACPropertyObserving)

- (RACObservableSequence *)observableSequenceForKeyPath:(NSString *)keyPath;
- (RACObservableSequence *)observableSequenceForBinding:(NSString *)binding;

@end
