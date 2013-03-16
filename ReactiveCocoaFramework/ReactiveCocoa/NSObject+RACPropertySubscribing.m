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
	RACSignal *signal =  [self rac_signalWithChangesFor:object keyPath:keyPath observer:observer];
	
	signal = [signal filter:^BOOL(NSDictionary *change) {
		BOOL isInitial = [change objectForKey:NSKeyValueChangeOldKey] == nil;
		BOOL isPrior = [[change objectForKey:NSKeyValueChangeNotificationIsPriorKey] boolValue];
		switch (type) {
			case RACAbleTypeCurrent:
			case RACAbleTypeCurrentWithPrevious:
			case RACAbleTypeInsert:
			case RACAbleTypeRemove:
			case RACAbleTypeReplacement:
				return ( ! isInitial && ! isPrior);
			case RACAbleTypeInitialCurrent:
			case RACAbleTypeInitialCurrentWithPrevious:
				return ( ! isPrior);
			case RACAbleTypePrior:
				return ( ! isInitial && isPrior);
		}
	}];
	signal = [signal filter:^BOOL(NSDictionary *change) {
		NSKeyValueChange kind = (NSKeyValueChange)[[change objectForKey:NSKeyValueChangeKindKey] integerValue];
		switch (type) {
			case RACAbleTypeCurrent:
			case RACAbleTypeInitialCurrent:
				return YES;
			case RACAbleTypeCurrentWithPrevious:
			case RACAbleTypeInitialCurrentWithPrevious:
			case RACAbleTypePrior:
				return (kind == NSKeyValueChangeSetting);
			case RACAbleTypeInsert:
				return (kind == NSKeyValueChangeInsertion);
			case RACAbleTypeRemove:
				return (kind == NSKeyValueChangeRemoval);
			case RACAbleTypeReplacement:
				return (kind == NSKeyValueChangeReplacement);
		}
	}];
	@unsafeify(object);
	signal = [signal map:^id(NSDictionary *change) {
		@strongify(object);
		id old = [change objectForKey:NSKeyValueChangeOldKey];
		id new = [change objectForKey:NSKeyValueChangeNewKey];
		NSIndexSet *indexes = [change objectForKey:NSKeyValueChangeIndexesKey];
		id currentValue = [object valueForKeyPath:keyPath];
		switch (type) {
			case RACAbleTypeCurrent:
			case RACAbleTypeInitialCurrent:
			case RACAbleTypePrior:
				return currentValue;
			case RACAbleTypeCurrentWithPrevious:
			case RACAbleTypeInitialCurrentWithPrevious:
				return RACTuplePackWithNils(old, new);
			case RACAbleTypeInsert:
				return RACTuplePackWithNils(new, indexes);
			case RACAbleTypeRemove:
				return RACTuplePackWithNils(old, indexes);
			case RACAbleTypeReplacement:
				return RACTuplePackWithNils(old, new, indexes);
		}
	}];
	
	return signal;
}

+ (RACSignal *)rac_signalWithChangesFor:(NSObject *)object keyPath:(NSString *)keyPath observer:(NSObject *)observer {
	@unsafeify(observer, object);
	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		NSKeyValueObservingOptions options = (NSKeyValueObservingOptionNew
											  | NSKeyValueObservingOptionOld
											  | NSKeyValueObservingOptionInitial
											  | NSKeyValueObservingOptionPrior);
		@strongify(observer, object);
		RACKVOTrampoline *KVOTrampoline = [object rac_addObserver:observer forKeyPath:keyPath options:options block:^(id target, id observer, NSDictionary *change) {
			[subscriber sendNext:change];
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
