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

static id (^nilPlaceHolder)(void) = ^{
	static id nilPlaceHolder = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    nilPlaceHolder = [[NSObject alloc] init];
	});
	return nilPlaceHolder;
};

@implementation NSObject (RACBindings)

- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath transformer:(id (^)(id))receiverTransformer onScheduler:(RACScheduler *)receiverScheduler toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath transformer:(id (^)(id))otherTransformer onScheduler:(RACScheduler *)otherScheduler {
	if (receiverScheduler == nil) receiverScheduler = RACScheduler.immediateScheduler;
	if (otherScheduler == nil) otherScheduler = RACScheduler.immediateScheduler;
	
	NSMutableArray *receiverBounces = NSMutableArray.array;
	NSMutableArray *otherBounces = NSMutableArray.array;
	
	static id (^addAsObserver)(id, id, NSString *, NSMutableArray *, id(^)(id), id, NSString *, NSMutableArray *, RACScheduler *, NSKeyValueObservingOptions) = ^(id observer, id target, NSString *targetKeyPath, NSMutableArray *targetBounces, id(^targetTransformer)(id), id boundObject, NSString *boundObjectKeyPath, NSMutableArray *boundObjectBounces, RACScheduler *boundObjectScheduler, NSKeyValueObservingOptions options){
		return [target rac_addObserver:observer forKeyPath:targetKeyPath options:options queue:nil block:^(id observer, NSDictionary *change) {
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
				@synchronized(boundObjectBounces) {
					[boundObjectBounces addObject:(value == nil ? nilPlaceHolder() : value)];
				}
				[boundObject setValue:value forKeyPath:boundObjectKeyPath];
			}];
		}];
	};
	
	id outgoingIdentifier = addAsObserver(self, self, receiverKeyPath, receiverBounces, receiverTransformer, otherObject, otherKeyPath, otherBounces, otherScheduler, 0);
	id incomingIdentifier = addAsObserver(self, otherObject, otherKeyPath, otherBounces, otherTransformer, self, receiverKeyPath, receiverBounces, receiverScheduler, NSKeyValueObservingOptionInitial);
		
	return [RACDisposable disposableWithBlock:^{
		[self rac_removeObserverWithIdentifier:outgoingIdentifier];
		[otherObject rac_removeObserverWithIdentifier:incomingIdentifier];
	}];
}

@end
