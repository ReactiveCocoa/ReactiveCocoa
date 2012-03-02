//
//  NSObject+RACPropertyObserving.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACPropertyObserving.h"
#import "NSObject+GHKVOWrapper.h"
#import "RACObservableSequence.h"
#import "RACObservableSequence+Private.h"
#import <objc/runtime.h>

static const NSUInteger RACObservableSequenceCountThreshold = 100; // I dunno


@implementation NSObject (RACPropertyObserving)

- (RACObservableSequence *)observableSequenceForKeyPath:(NSString *)keyPath {
	RACObservableSequence *array = [RACObservableSequence sequenceWithCapacity:RACObservableSequenceCountThreshold];
	__unsafe_unretained NSObject *weakSelf = self;
	[self addObserver:array forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		[array addObjectAndNilsAreOK:[strongSelf valueForKeyPath:keyPath]];
	}];
	
	return array;
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
}

@end
