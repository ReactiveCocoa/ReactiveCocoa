//
//  NSObject+RACPropertySubscribing.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/2/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "EXTScope.h"
#import "RACKVOTrampoline.h"
#import "RACCompoundDisposable.h"
#import "RACTuple.h"
#import <objc/runtime.h>

static const void *RACObjectCompoundDisposable = &RACObjectCompoundDisposable;
static const void *RACObjectScopedDisposable = &RACObjectScopedDisposable;

@implementation NSObject (RACPropertySubscribing)

+ (RACSignal *)rac_signalFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer type:(RACAbleType)type {
	@unsafeify(observer, object);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSKeyValueObservingOptions options = (NSKeyValueObservingOptionNew
											  | NSKeyValueObservingOptionOld);
		if (type == RACAbleTypeInitialCurrent
			|| type == RACAbleTypeInitialCurrentWithPrevious) {
			options |= NSKeyValueObservingOptionInitial;
		}
		if (type == RACAbleTypePrior) {
			options |= NSKeyValueObservingOptionPrior;
		}
		
		@strongify(observer, object);
		RACKVOTrampoline *KVOTrampoline = [object rac_addObserver:observer forKeyPath:keyPath options:options block:^(id target, id observer, NSDictionary *change) {
			BOOL isPrior = [[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue];
			NSKeyValueChange kind = (NSKeyValueChange)[[change objectForKey:NSKeyValueChangeKindKey] integerValue];
			id old = [change objectForKey:NSKeyValueChangeOldKey];
			id new = [change objectForKey:NSKeyValueChangeNewKey];
			NSIndexSet *indexes = [change objectForKey:NSKeyValueChangeIndexesKey];
			id currentValue = [target valueForKeyPath:keyPath];
			
			id nextValue = nil;
			BOOL shouldSendNext = YES;
			switch (type) {
				case RACAbleTypeCurrent:
				case RACAbleTypeInitialCurrent:
					nextValue = currentValue;
					break;
				case RACAbleTypeCurrentWithPrevious:
				case RACAbleTypeInitialCurrentWithPrevious:
					if (kind == NSKeyValueChangeSetting) {
						nextValue = RACTuplePackWithNils(old, new);
					}
					else {
						shouldSendNext = NO;
					}
					break;
				case RACAbleTypePrior:
					if (isPrior && kind == NSKeyValueChangeSetting) {
						nextValue = old;
					}
					else {
						shouldSendNext = NO;
					}
					break;
				case RACAbleTypeInsert:
					if (kind == NSKeyValueChangeInsertion) {
						nextValue = RACTuplePackWithNils(new, indexes);
					}
					else {
						shouldSendNext = NO;
					}
					break;
				case RACAbleTypeRemove:
					if (kind == NSKeyValueChangeRemoval) {
						nextValue = RACTuplePackWithNils(old, indexes);
					}
					else {
						shouldSendNext = NO;
					}
					break;
				case RACAbleTypeReplacement:
					if (kind == NSKeyValueChangeReplacement) {
						nextValue = RACTuplePackWithNils(old, new, indexes);
					}
					else {
						shouldSendNext = NO;
					}
					break;
			}
			if (shouldSendNext) {
				[subscriber sendNext:nextValue];
			}
		}];
		
		RACDisposable *KVODisposable = [RACDisposable disposableWithBlock:^{
			[KVOTrampoline stopObserving];
		}];
		
		@weakify(subscriber);
		RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
			@strongify(subscriber);
			[KVODisposable dispose];
			[subscriber sendCompleted];
		}];
		
		[observer rac_addDeallocDisposable:deallocDisposable];
		[object rac_addDeallocDisposable:deallocDisposable];
		
		RACCompoundDisposable *observerDisposable = observer.rac_deallocDisposable;
		RACCompoundDisposable *objectDisposable = object.rac_deallocDisposable;
		return [RACDisposable disposableWithBlock:^{
			[observerDisposable removeDisposable:deallocDisposable];
			[objectDisposable removeDisposable:deallocDisposable];
			[KVODisposable dispose];
		}];
	}] setNameWithFormat:@"RACAble(%@, %@)", object, keyPath];
}

- (RACSignal *)rac_signalForKeyPath:(NSString *)keyPath observer:(NSObject *)observer type:(RACAbleType)type {
	return [self.class rac_signalFor:self keyPath:keyPath observer:observer type:type];
}

- (RACDisposable *)rac_deriveProperty:(NSString *)keyPath from:(RACSignal *)signal {
	return [signal toProperty:keyPath onObject:self];
}

- (RACCompoundDisposable *)rac_deallocDisposable {
	@synchronized(self) {
		RACCompoundDisposable *compoundDisposable = objc_getAssociatedObject(self, RACObjectCompoundDisposable);
		if (compoundDisposable == nil) {
			compoundDisposable = [RACCompoundDisposable compoundDisposable];
			objc_setAssociatedObject(self, RACObjectCompoundDisposable, compoundDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
			objc_setAssociatedObject(self, RACObjectScopedDisposable, compoundDisposable.asScopedDisposable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		}
		
		return compoundDisposable;
	}
}

- (void)rac_addDeallocDisposable:(RACDisposable *)disposable {
	[self.rac_deallocDisposable addDisposable:disposable];
}

@end
