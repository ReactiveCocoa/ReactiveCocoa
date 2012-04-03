//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import <objc/runtime.h>
#import "NSObject+RACKVOWrapper.h"
#import "RACValueTransformer.h"
#import "RACReplaySubject.h"
#import "RACScopedDisposable.h"

static const void *RACPropertySubscribingDisposables = &RACPropertySubscribingDisposables;


@implementation NSObject (RACPropertySubscribing)

+ (RACSubscribable *)RACSubscribableFor:(NSObject *)object keyPath:(NSString *)keyPath {
	RACReplaySubject *subject = [RACReplaySubject replaySubjectWithCapacity:1];
	
	NSMutableSet *disposables = objc_getAssociatedObject(object, RACPropertySubscribingDisposables);
	if(disposables == nil) {
		disposables = [NSMutableSet set];
		objc_setAssociatedObject(object, RACPropertySubscribingDisposables, disposables, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	__block __unsafe_unretained id weakSubject = subject;
	[disposables addObject:[RACScopedDisposable disposableWithBlock:^{
		RACReplaySubject *strongSubject = weakSubject;
		[strongSubject sendCompleted];
	}]];
	
	__block __unsafe_unretained NSObject *weakSelf = object;
	[object rac_addObserver:object forKeyPath:keyPath options:0 queue:[NSOperationQueue mainQueue] block:^(id target, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		[subject sendNext:[strongSelf valueForKeyPath:keyPath]];
	}];
	
	return subject;
}

- (RACSubscribable *)RACSubscribableForKeyPath:(NSString *)keyPath {
	return [[self class] RACSubscribableFor:self keyPath:keyPath];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath nilValue:nil];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath nilValue:(id)nilValue {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nilValue, NSNullPlaceholderBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withKeyPath:(NSString *)keyPath transform:(id (^)(id value))transformBlock {
	RACValueTransformer *transformer = [RACValueTransformer transformerWithBlock:transformBlock];
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, transformer, NSValueTransformerBindingOption, nil]];
}

- (void)bind:(NSString *)binding toObject:(id)object withNegatedKeyPath:(NSString *)keyPath {
	[self bind:binding toObject:object withKeyPath:keyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
}

@end
