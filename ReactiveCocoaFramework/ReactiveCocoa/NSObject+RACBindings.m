//
//  NSObject+RACBindings.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACBindings.h"
#import "RACSignal.h"
#import "NSObject+RACKVOWrapper.h"
#import "RACSubject.h"
#import "RACDisposable.h"
#import "RACScheduler.h"

@implementation NSObject (RACBindings)

- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath transformer:(id (^)(id))receiverTransformer onScheduler:(RACScheduler *)receiverScheduler toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath transformer:(id (^)(id))otherTransformer onScheduler:(RACScheduler *)otherScheduler {
	static id (^nilPlaceHolder)(void) = ^{
		static id nilPlaceHolder = nil;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			nilPlaceHolder = [[NSObject alloc] init];
		});
		return nilPlaceHolder;
	};
	
	if (receiverScheduler == nil) receiverScheduler = RACScheduler.immediateScheduler;
	if (otherScheduler == nil) otherScheduler = RACScheduler.immediateScheduler;
	
	NSMutableArray *receiverBounces = NSMutableArray.array;
	NSMutableArray *otherBounces = NSMutableArray.array;
	
	__block volatile int32_t versionCounter = -1;
	__block int32_t receiverVersionLowerBound = -1;
	__block int32_t otherVersionLowerBound = 0;
	__block volatile int32_t *versionCounterPtr = &versionCounter;
	__block int32_t *receiverVersionLowerBoundPtr = &receiverVersionLowerBound;
	__block int32_t *otherVersionLowerBoundPtr = &otherVersionLowerBound;
	
	static id (^addAsObserver)(id, id, NSString *, NSMutableArray *, int32_t *, id(^)(id), id, NSString *, NSMutableArray *, int32_t *, RACScheduler *, volatile int32_t *, NSKeyValueObservingOptions) = ^(id observer, id target, NSString *targetKeyPath, NSMutableArray *targetBounces, int32_t *targetVersionLowerBound, id(^targetTransformer)(id), id boundObject, NSString *boundObjectKeyPath, NSMutableArray *boundObjectBounces, int32_t *boundObjectVersionLowerBound, RACScheduler *boundObjectScheduler, volatile int32_t *versionCounter, NSKeyValueObservingOptions options){
		return [target rac_addObserver:observer forKeyPath:targetKeyPath options:options queue:nil block:^(id observer, NSDictionary *change) {
			int32_t currentVersion = OSAtomicIncrement32(versionCounter);
			*targetVersionLowerBound = currentVersion;
			id value = [target valueForKeyPath:targetKeyPath];
			
			@synchronized(targetBounces) {
				for (NSUInteger i = 0; i < targetBounces.count; ++i) {
					if ([targetBounces[i] isEqual:(value == nil ? nilPlaceHolder() : value)]) {
						[targetBounces removeObjectAtIndex:i];
						return;
					}
				}
			}
			
			if (targetTransformer != nil) value = targetTransformer(value);
			
			[boundObjectScheduler schedule:^{
				if (*boundObjectVersionLowerBound > currentVersion) return;
				@synchronized(boundObjectBounces) {
					[boundObjectBounces addObject:(value == nil ? nilPlaceHolder() : value)];
				}
				[boundObject setValue:value forKeyPath:boundObjectKeyPath];
			}];
		}];
	};
	
	id outgoingIdentifier = addAsObserver(self, self, receiverKeyPath, receiverBounces, receiverVersionLowerBoundPtr, receiverTransformer, otherObject, otherKeyPath, otherBounces, otherVersionLowerBoundPtr, otherScheduler, versionCounterPtr, 0);
	id incomingIdentifier = addAsObserver(self, otherObject, otherKeyPath, otherBounces, otherVersionLowerBoundPtr, otherTransformer, self, receiverKeyPath, receiverBounces, receiverVersionLowerBoundPtr, receiverScheduler, versionCounterPtr, NSKeyValueObservingOptionInitial);
		
	return [RACDisposable disposableWithBlock:^{
		[self rac_removeObserverWithIdentifier:outgoingIdentifier];
		[otherObject rac_removeObserverWithIdentifier:incomingIdentifier];
	}];
}

@end
