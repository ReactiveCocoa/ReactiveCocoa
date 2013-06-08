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
#import "RACKVOTrampoline.h"
#import "NSObject+RACPropertySubscribing.h"

@implementation NSObject (RACObservablePropertyObserving)

- (RACDisposable *)rac_addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath willChangeBlock:(void (^)(BOOL))willChangeBlock didChangeBlock:(void (^)(BOOL, id))didChangeBlock {
	NSCParameterAssert(keyPath.rac_keyPathComponents.count > 0);
	NSArray *keyPathComponents = keyPath.rac_keyPathComponents;
	NSUInteger keyPathComponentsCount = keyPathComponents.count;
	NSString *firstKeyPathComponent = keyPathComponents[0];
	NSString *keyPathByDeletingFirstKeyPathComponent = keyPath.rac_keyPathByDeletingFirstKeyPathComponent;
	
	@unsafeify(observer);
	RACCompoundDisposable *disposable = [RACCompoundDisposable compoundDisposable];
	__block RACCompoundDisposable *childDisposable = nil;
	
	RACKVOTrampoline *trampoline = [self rac_addObserver:observer forKeyPath:firstKeyPathComponent options:NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionInitial block:^(id trampolineTarget, id trampolineObserver, NSDictionary *change) {
		@strongify(observer);
		
		if (keyPathComponentsCount > 1) {
			NSObject *value = [trampolineTarget valueForKey:firstKeyPathComponent];
			if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
				if (value == nil) {
					@synchronized (observer) {
						willChangeBlock(NO);
					}
				}
			} else {
				if (value != nil) {
					@synchronized (disposable) {
						[childDisposable dispose];
						[disposable removeDisposable:childDisposable];
						childDisposable = [RACCompoundDisposable compoundDisposable];
						[disposable addDisposable:childDisposable];
					}
					[childDisposable addDisposable:[value rac_addObserver:observer forKeyPath:keyPathByDeletingFirstKeyPathComponent willChangeBlock:willChangeBlock didChangeBlock:didChangeBlock]];
					
					RACCompoundDisposable *valueDisposable = value.rac_deallocDisposable;
					RACDisposable *deallocDisposable = [RACDisposable disposableWithBlock:^{
						@strongify(observer);
						@synchronized (observer) {
							didChangeBlock(NO, nil);
						}
					}];
					[valueDisposable addDisposable:deallocDisposable];
					[childDisposable addDisposable:[RACDisposable disposableWithBlock:^{
						[valueDisposable removeDisposable:deallocDisposable];
					}]];
				} else {
					@synchronized (observer) {
						didChangeBlock(NO, nil);
					}
				}
			}
		} else {
			if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
				@synchronized (observer) {
					willChangeBlock(YES);
				}
			} else {
				@synchronized (observer) {
					didChangeBlock(YES, [trampolineTarget valueForKey:firstKeyPathComponent]);
				}
			}
		}
	}];
	
	[disposable addDisposable:[RACDisposable disposableWithBlock:^{
		[trampoline stopObserving];
	}]];
	return disposable;
}

@end
