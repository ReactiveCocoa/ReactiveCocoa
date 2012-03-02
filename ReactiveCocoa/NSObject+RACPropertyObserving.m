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

static const void *RACObservableSequenceKey = &RACObservableSequenceKey;
static NSString * const RACPropertyObservingBindingKeyPath = @"RACPropertyObservingBindingValue";

@interface NSObject ()
@property (nonatomic, strong) RACObservableSequence *RACObservableSequence;
@end


@implementation NSObject (RACPropertyObserving)

- (RACObservableSequence *)observableSequenceForKeyPath:(NSString *)keyPath {
	RACObservableSequence *array = [RACObservableSequence sequence];
	__unsafe_unretained NSObject *weakSelf = self;
	[self addObserver:array forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		
		[[strongSelf class] pruneObservingArray:array];
		
		[array addObjectAndNilsAreOK:[strongSelf valueForKeyPath:keyPath]];
	}];
	
	return array;
}

- (RACObservableSequence *)observableSequenceForBinding:(NSString *)binding {
	self.RACObservableSequence = [RACObservableSequence sequence];
	
	[self bind:binding toObject:self withKeyPath:RACPropertyObservingBindingKeyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	return self.RACObservableSequence;
}

- (RACObservableSequence *)RACObservableSequence {
	return objc_getAssociatedObject(self, RACObservableSequenceKey);
}

- (void)setRACObservableSequence:(RACObservableSequence *)a {
	objc_setAssociatedObject(self, RACObservableSequenceKey, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setRACPropertyObservingBindingValue:(id)value {
	[[self class] pruneObservingArray:self.RACObservableSequence];
	
	[self.RACObservableSequence addObjectAndNilsAreOK:value];
}

- (id)RACPropertyObservingBindingValue {
	return [self.RACObservableSequence lastObject];
}

+ (void)pruneObservingArray:(RACObservableSequence *)sequence {
	while(sequence.count > RACObservableSequenceCountThreshold) {
		[sequence removeFirstObject];
	}
}

@end
