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

static id (^nilPlaceHolder)(void) = ^{
	static id nilPlaceHolder = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    nilPlaceHolder = [[NSObject alloc] init];
	});
	return nilPlaceHolder;
};

RACSignalTransformationBlock const RACSignalTransformationIdentity = ^(id<RACSignal> signal) {
	return signal;
};

@implementation NSObject (RACBindings)

- (RACDisposable *)rac_bind:(NSString *)receiverKeyPath signalBlock:(RACSignalTransformationBlock)receiverSignalBlock toObject:(id)otherObject withKeyPath:(NSString *)otherKeyPath signalBlock:(RACSignalTransformationBlock)otherSignalBlock {
	NSParameterAssert(receiverSignalBlock != nil);
	NSParameterAssert(otherSignalBlock != nil);
		
	NSMutableArray *expectedReceiverBounces = NSMutableArray.array;
	NSMutableArray *expectedOtherBounces = NSMutableArray.array;
	
	RACSubject *outgoingSubject = RACSubject.subject;
	RACDisposable *outgoingDisposable = [otherSignalBlock(outgoingSubject) subscribeNext:^(id x) {
		@synchronized(expectedOtherBounces) {
			[expectedOtherBounces addObject:x ?: nilPlaceHolder()];
		}
		[otherObject setValue:x forKeyPath:otherKeyPath];
	}];
	
	id outgoingIdentifier = [self rac_addObserver:self forKeyPath:receiverKeyPath options:0 queue:nil block:^(id observer, NSDictionary *change) {
		id value = [self valueForKeyPath:receiverKeyPath];
		if (value == nil) {
			value = nilPlaceHolder();
		}
		@synchronized(expectedReceiverBounces) {
			for (NSUInteger i = 0; i < expectedReceiverBounces.count; ++i) {
				if ([expectedReceiverBounces[i] isEqual:value]) {
					[expectedReceiverBounces removeObjectAtIndex:i];
					return;
				}
			}
		}
		if (value == nilPlaceHolder()) {
			value = nil;
		}
		[outgoingSubject sendNext:value];
	}];
	
	RACSubject *incomingSubject = RACSubject.subject;
	RACDisposable *incomingDisposable = [receiverSignalBlock(incomingSubject) subscribeNext:^(id x) {
		@synchronized(expectedReceiverBounces) {
			[expectedReceiverBounces addObject:x ?: nilPlaceHolder()];
		}
		[self setValue:x forKeyPath:receiverKeyPath];
	}];
	
	id incomingIdentifier = [otherObject rac_addObserver:self forKeyPath:otherKeyPath options:NSKeyValueObservingOptionInitial queue:nil block:^(id observer, NSDictionary *change) {
		id value = [otherObject valueForKeyPath:otherKeyPath];
		if (value == nil) {
			value = nilPlaceHolder();
		}
		@synchronized(expectedOtherBounces) {
			for (NSUInteger i = 0; i < expectedOtherBounces.count; ++i) {
				if ([expectedOtherBounces[i] isEqual:value]) {
					[expectedOtherBounces removeObjectAtIndex:i];
					return;
				}
			}
		}
		if (value == nilPlaceHolder()) {
			value = nil;
		}
		[incomingSubject sendNext:value];
	}];
	
	return [RACDisposable disposableWithBlock:^{
		[incomingDisposable dispose];
		[otherObject rac_removeObserverWithIdentifier:incomingIdentifier];
		[outgoingDisposable dispose];
		[self rac_removeObserverWithIdentifier:outgoingIdentifier];
	}];
}

@end
