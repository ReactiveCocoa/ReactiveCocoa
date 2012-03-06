//
//  NSObject+RACPropertyObserving.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACPropertyObserving.h"
#import "NSObject+GHKVOWrapper.h"
#import "RACSequence.h"
#import "RACSequence+Private.h"
#import "RACValue.h"

#import <objc/runtime.h>

static const NSUInteger RACObservableSequenceCountThreshold = 100; // I dunno


@implementation NSObject (RACPropertyObserving)

- (RACSequence *)RACSequenceForKeyPath:(NSString *)keyPath {
	RACSequence *sequence = [RACSequence sequenceWithCapacity:RACObservableSequenceCountThreshold];
	__unsafe_unretained NSObject *weakSelf = self;
	[self addObserver:sequence forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		[sequence addObjectAndNilsAreOK:[strongSelf valueForKeyPath:keyPath]];
	}];
	
	return sequence;
}

- (RACValue *)RACValueForKeyPath:(NSString *)keyPath {
	RACValue *value = [RACValue value];
	__unsafe_unretained NSObject *weakSelf = self;
	[self addObserver:value forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		value.value = [strongSelf valueForKeyPath:keyPath];
	}];
	
	return value;
}

- (void)bind:(NSString *)binding toValue:(RACValue *)value {
	[self bind:binding toObject:value withKeyPath:@"value" options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
}

@end
