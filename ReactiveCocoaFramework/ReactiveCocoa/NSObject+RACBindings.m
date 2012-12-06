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
	
	__block volatile uint32_t versionCounter = 0;
	__block volatile uint32_t receiverVersionLowerBound = 0;
	__block volatile uint32_t otherVersionLowerBound = 0;
	
	id outgoingIdentifier = [self rac_addObserver:self forKeyPath:receiverKeyPath options:0 queue:nil block:^(id observer, NSDictionary *change) {
		uint32_t currentVersion = __sync_fetch_and_add(&versionCounter, 1);
		receiverVersionLowerBound = currentVersion;
		id value = [self valueForKeyPath:receiverKeyPath];
		
		@synchronized(receiverBounces) {
			for (NSUInteger i = 0; i < receiverBounces.count; ++i) {
				if ([receiverBounces[i] isEqual:(value == nil ? nilPlaceHolder() : value)]) {
					[receiverBounces removeObjectAtIndex:i];
					return;
				}
			}
		}
		
		if (receiverTransformer != nil) value = receiverTransformer(value);
		
		[otherScheduler schedule:^{
			if (currentVersion - otherVersionLowerBound > UINT32_MAX / 2) return;
			@synchronized(otherBounces) {
				[otherBounces addObject:(value == nil ? nilPlaceHolder() : value)];
			}
			[otherObject setValue:value forKeyPath:otherKeyPath];
		}];
	}];
	
	id incomingIdentifier = [otherObject rac_addObserver:self forKeyPath:otherKeyPath options:NSKeyValueObservingOptionInitial queue:nil block:^(id observer, NSDictionary *change) {
		uint32_t currentVersion = __sync_fetch_and_add(&versionCounter, 1);
		otherVersionLowerBound = currentVersion;
		id value = [otherObject valueForKeyPath:otherKeyPath];
		
		@synchronized(otherBounces) {
			for (NSUInteger i = 0; i < otherBounces.count; ++i) {
				if ([otherBounces[i] isEqual:(value == nil ? nilPlaceHolder() : value)]) {
					[otherBounces removeObjectAtIndex:i];
					return;
				}
			}
		}
		
		if (otherTransformer != nil) value = otherTransformer(value);
		
		[receiverScheduler schedule:^{
			if (currentVersion - receiverVersionLowerBound > UINT32_MAX / 2) return;
			@synchronized(receiverBounces) {
				[receiverBounces addObject:(value == nil ? nilPlaceHolder() : value)];
			}
			[self setValue:value forKeyPath:receiverKeyPath];
		}];
	}];

	return [RACDisposable disposableWithBlock:^{
		[self rac_removeObserverWithIdentifier:outgoingIdentifier];
		[otherObject rac_removeObserverWithIdentifier:incomingIdentifier];
	}];
}

@end
