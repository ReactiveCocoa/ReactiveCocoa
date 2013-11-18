//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"
#import "RACSubscriber.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import <libkern/OSAtomic.h>

@implementation NSObject (RACPropertySubscribing)

- (RACSignal *)rac_valuesForKeyPath:(NSString *)keyPath observer:(NSObject *)observer {
	return [[[self rac_valuesAndChangesForKeyPath:keyPath options:NSKeyValueObservingOptionInitial observer:observer] reduceEach:^(id value, NSDictionary *change) {
		return value;
	}] setNameWithFormat:@"RACObserve(%@, %@)", self.rac_description, keyPath];
}

- (RACSignal *)rac_valuesAndChangesForKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options observer:(NSObject *)observer {
	keyPath = [keyPath copy];

	RACDisposable *deallocFlagDisposable = [[RACDisposable alloc] init];
	RACCompoundDisposable *observerDisposable = observer.rac_deallocDisposable;
	RACCompoundDisposable *objectDisposable = self.rac_deallocDisposable;
	[observerDisposable addDisposable:deallocFlagDisposable];
	[objectDisposable addDisposable:deallocFlagDisposable];

	@unsafeify(self, observer);
	return [RACSignal create:^(id<RACSubscriber> subscriber) {
		if (deallocFlagDisposable.disposed) {
			[subscriber sendCompleted];
			return;
		}

		@strongify(self, observer);

		RACDisposable *observationDisposable = [self rac_observeKeyPath:keyPath options:options observer:observer block:^(id value, NSDictionary *change) {
			[subscriber sendNext:RACTuplePack(value, change)];
		}];

		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			[observationDisposable dispose];
			[subscriber sendCompleted];
		}];

		[observer.rac_deallocDisposable addDisposable:deallocDisposable];
		[self.rac_deallocDisposable addDisposable:deallocDisposable];

		[subscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
			[observerDisposable removeDisposable:deallocFlagDisposable];
			[objectDisposable removeDisposable:deallocFlagDisposable];
			[observerDisposable removeDisposable:deallocDisposable];
			[objectDisposable removeDisposable:deallocDisposable];
			[observationDisposable dispose];
		}]];
	}];
}

@end
