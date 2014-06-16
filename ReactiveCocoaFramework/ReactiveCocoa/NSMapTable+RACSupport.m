//
//  NSMapTable+RACSupport.m
//  ReactiveCocoa
//
//  Created by Syo Ikeda on 2013-12-24.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSMapTable+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"
#import "RACTuple.h"

@implementation NSMapTable (RACSupport)

- (RACSignal *)rac_signal {
	NSMapTable *collection = [self copy];

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		for (id key in collection) {
			id object = [collection objectForKey:key];
			[subscriber sendNext:RACTuplePack(key, object)];

			if (subscriber.disposable.disposed) return;
		}

		[subscriber sendCompleted];
	}] setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

- (RACSignal *)rac_keySignal {
	return [[self.rac_signal reduceEach:^(id key, id object) {
		return key;
	}] setNameWithFormat:@"%@ -rac_keySignal", self.rac_description];
}

- (RACSignal *)rac_valueSignal {
	return [[self.rac_signal reduceEach:^(id key, id object) {
		return object;
	}] setNameWithFormat:@"%@ -rac_valueSignal", self.rac_description];
}

@end
