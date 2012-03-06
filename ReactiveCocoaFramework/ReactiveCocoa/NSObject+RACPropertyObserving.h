//
//  NSObject+RACPropertyObserving.h
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RACKVO(property) ((void)(NO && ((void)property, NO)), @#property)
#define RACObservable(property) [self RACValueForKeyPath:RACKVO(self.property)]

@class RACSequence;
@class RACValue;


@interface NSObject (RACPropertyObserving)

// Creates a sequence from observing the value at the given keypath.
- (RACSequence *)RACSequenceForKeyPath:(NSString *)keyPath;

// Creates a value from observing the value at the given keypath.
- (RACValue *)RACValueForKeyPath:(NSString *)keyPath;

// Bind the given binding to the value.
- (void)bind:(NSString *)binding toValue:(RACValue *)value;

// Calls -[NSObject bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]]
- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath;

@end
