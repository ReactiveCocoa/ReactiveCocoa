//
//  NSObject+RACPropertyObserving.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACPropertyObserving.h"
#import "NSObject+GHKVOWrapper.h"
#import "RACObservableArray.h"
#import "RACObservableArray+Private.h"
#import <objc/runtime.h>

static const void *RACObservableArrayKey = &RACObservableArrayKey;
static NSString * const RACPropertyObservingBindingKeyPath = @"RACPropertyObservingBindingValue";

@interface NSObject ()
@property (nonatomic, strong) RACObservableArray *RACObservableArray;
@end


@implementation NSObject (RACPropertyObserving)

- (id<RACObservable>)observableForKeyPath:(NSString *)keyPath {
	RACObservableArray *array = [RACObservableArray array];
	__unsafe_unretained NSObject *weakSelf = self;
	[self addObserver:array forKeyPath:keyPath options:0 queue:nil block:^(id target, NSDictionary *change) {
		NSObject *strongSelf = weakSelf;
		[array addObjectAndNilsAreOK:[strongSelf valueForKeyPath:keyPath]];
	}];
	
	return array;
}

- (id<RACObservable>)observableForBinding:(NSString *)binding {
	self.RACObservableArray = [RACObservableArray array];
	
	[self bind:binding toObject:self withKeyPath:RACPropertyObservingBindingKeyPath options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];
	
	return self.RACObservableArray;
}

- (RACObservableArray *)RACObservableArray {
	return objc_getAssociatedObject(self, RACObservableArrayKey);
}

- (void)setRACObservableArray:(RACObservableArray *)a {
	objc_setAssociatedObject(self, RACObservableArrayKey, a, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setRACPropertyObservingBindingValue:(id)value {
	[self.RACObservableArray addObjectAndNilsAreOK:value];
}

- (id)RACPropertyObservingBindingValue {
	return [self.RACObservableArray lastObject];
}

@end
