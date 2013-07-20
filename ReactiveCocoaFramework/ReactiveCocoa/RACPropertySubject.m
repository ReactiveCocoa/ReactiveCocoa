//
//  RACPropertySubject.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 16/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject.h"
#import "EXTScope.h"
#import "RACBinding+Private.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSubscriber+Private.h"
#import "RACTuple.h"

@interface RACPropertySubject ()

// A replay subject of capacity 1 that holds the current value of the property
// and the binding that value was sent to in a tuple. The binding will be nil if
// the value was sent to the property directly.
@property (nonatomic, readonly, strong) RACReplaySubject *currentValueAndSender;

@end

@implementation RACPropertySubject

#pragma mark API

+ (instancetype)property {
	RACPropertySubject *property = [[self alloc] init];
	if (property == nil) return nil;
	@weakify(property);

	RACReplaySubject *currentValueAndSender = [RACReplaySubject replaySubjectWithCapacity:1];
	[currentValueAndSender sendNext:[RACTuple tupleWithObjects:RACTupleNil.tupleNil, RACTupleNil.tupleNil, nil]];

	property->_currentValueAndSender = currentValueAndSender;

	property.signal = [currentValueAndSender map:^(RACTuple *value) {
		return value.first;
	}];

	property.subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		[currentValueAndSender sendNext:RACTuplePack(x, RACTupleNil.tupleNil)];
	} error:^(NSError *error) {
		@strongify(property);
		NSCAssert(NO, @"Received error in RACPropertySubject %@: %@", property, error);

		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACPropertySubject %@: %@", property, error);
	} completed:^{
		[currentValueAndSender sendCompleted];
	}];

	return property;
}

- (RACBinding *)binding {
	RACReplaySubject *currentValueAndSender = self.currentValueAndSender;
	
	RACBinding *binding = [[RACBinding alloc] init];
	if (binding == nil) return nil;
	@weakify(binding);

	binding.signal = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		__block BOOL isFirstNext = YES;
		return [currentValueAndSender subscribeNext:^(RACTuple *x) {
			@strongify(binding);

			if (isFirstNext || ![x.second isEqual:binding]) {
				isFirstNext = NO;
				[subscriber sendNext:x.first];
			}
		} completed:^{
			[subscriber sendCompleted];
		}];
	}];

	binding.subscriber = [RACSubscriber subscriberWithNext:^(id x) {
		@strongify(binding);

		[currentValueAndSender sendNext:RACTuplePack(x, binding)];
	} error:^(NSError *error) {
		@strongify(binding);

		NSCAssert(NO, @"Received error in RACBinding %@: %@", binding, error);
		// Log the error if we're running with assertions disabled.
		NSLog(@"Received error in RACBinding %@: %@", binding, error);

		[currentValueAndSender sendError:error];
	} completed:^{
		[currentValueAndSender sendCompleted];
	}];

	return binding;
}

@end
