//
//  NSObject+RACObservablePropertyObserving.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 08/06/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACObservablePropertyObserving.h"
#import "EXTScope.h"
#import "NSString+RACKeyPathUtilities.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACKVOTrampoline.h"
#import "NSObject+RACPropertySubscribing.h"

@implementation NSObject (RACObservablePropertyObserving)

- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void (^)(BOOL))willChangeBlock didChangeBlock:(void (^)(BOOL, id))didChangeBlock {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	NSCParameterAssert(willChangeBlock != nil || didChangeBlock != nil);
	id synchronizationToken = willChangeBlock;
	if (synchronizationToken == nil) synchronizationToken = didChangeBlock;
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *firstKeyPathComponent = keyPathComponents[0];
	NSString *keyPathByDeletingFirstKeyPathComponent = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;

	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	__block RACCompoundDisposable *childDisposable = nil;
	
	RACKVOTrampoline *trampoline = [self rac_addObserver:observer forKeyPath:firstKeyPathComponent options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionInitial block:^(id trampolineTarget, id trampolineObserver, NSDictionary *change) {
		
		NSObject *value = [trampolineTarget valueForKey:firstKeyPathComponent];

		@synchronized (disposable) {
			[childDisposable dispose];
			[disposable removeDisposable:childDisposable];
			if (![change[NSKeyValueChangeNotificationIsPriorKey] boolValue] && value != nil) {
				childDisposable = [RACCompoundDisposable compoundDisposable];
				[disposable addDisposable:childDisposable];
			}
		}

		if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
			if (willChangeBlock != nil) {
				@synchronized (synchronizationToken) {
					willChangeBlock(keyPathComponentsCount == 1);
				}
			}
			return;
		}

		if (value == nil) {
			if (didChangeBlock != nil) {
				@synchronized (synchronizationToken) {
					didChangeBlock(keyPathComponentsCount == 1, nil);
				}
			}
			return;
		}

		if (didChangeBlock != nil) {
			RACCompoundDisposable *valueDisposable = value.rac_deallocDisposable;
			RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
				@synchronized (synchronizationToken) {
					didChangeBlock(keyPathComponentsCount == 1, nil);
				}
			}];
			[valueDisposable addDisposable:deallocDisposable];
			[childDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				[valueDisposable removeDisposable:deallocDisposable];
			}]];
		}

		if (keyPathComponentsCount == 1) {
			if (didChangeBlock != nil) {
				didChangeBlock(YES, value);
			}
			return;
		}

		[childDisposable addDisposable:[value rac_addObserver:observer forKeyPath:keyPathByDeletingFirstKeyPathComponent willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock]];
	}];
	
	[disposable addDisposable:[RACDisposable disposableWithBlock:^{
		[trampoline stopObserving];
	}]];

	[observer rac_addDeallocDisposable:disposable];
	[self rac_addDeallocDisposable:disposable];

	return disposable;
}

@end
