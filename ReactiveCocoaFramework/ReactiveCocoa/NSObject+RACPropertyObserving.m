//
//  NSObject+RACPropertyObserving.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACPropertyObserving.h"
#import "NSObject+GHKVOWrapper.h"
#import "RACValueTransformer.h"
#import "RACReplaySubject.h"


@implementation NSObject (RACPropertyObserving)

- (id<RACObservable>)RACObservableForKeyPath:(NSString *)keyPath {
	RACReplaySubject *subject = [RACReplaySubject replaySubjectWithCapacity:1];
	__unsafe_unretained NSObject *weakSelf = self;
	[self addObserver:subject forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(RACReplaySubject *s, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		[s sendNext:[strongSelf valueForKeyPath:keyPath]];
	}];
	
	return subject;
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock {
	RACValueTransformer *transformer = [RACValueTransformer transformerWithBlock:transformBlock];
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, transformer, NSValueTransformerBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
}

@end
