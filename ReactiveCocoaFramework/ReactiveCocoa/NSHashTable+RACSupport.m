//
//  NSHashTable+RACSupport.m
//  ReactiveCocoa
//
//  Created by Syo Ikeda on 2013-12-21.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSHashTable+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSHashTable (RACSupport)

- (RACSignal *)rac_signal {
	NSHashTable *collection = [self copy];

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		for (id obj in collection) {
			[subscriber sendNext:obj];

			if (subscriber.disposable.disposed) return;
		}

		[subscriber sendCompleted];
	}] setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

@end
