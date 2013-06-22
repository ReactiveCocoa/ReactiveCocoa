//
//  NSObject+RACLifting.m
//  iOSDemo
//
//  Created by Josh Abernathy on 10/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "EXTScope.h"
#import "NSInvocation+RACTypeParsing.h"
#import "NSObject+RACDeallocating.h"
#import "RACBlockTrampoline.h"
#import "RACCompoundDisposable.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import "RACUnit.h"

@implementation NSObject (RACLifting)

- (RACSignal *)rac_liftSignals:(NSArray *)signals withReducingInvocation:(id (^)(RACTuple *))reduceBlock {
	RACMulticastConnection *connection = [[[RACSignal
		combineLatest:signals]
		map:reduceBlock]
		multicast:[RACReplaySubject replaySubjectWithCapacity:1]];

	RACDisposable *disposable = [connection connect];
	[self.rac_deallocDisposable addDisposable:disposable];

	return connection.signal;
}

- (RACSignal *)rac_liftSelector:(SEL)selector withSignalsFromArray:(NSArray *)signals {
	NSCParameterAssert(selector != NULL);
	NSCParameterAssert(signals != nil);
	NSCParameterAssert(signals.count > 0);

	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSCAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSUInteger numberOfArguments __attribute__((unused)) = methodSignature.numberOfArguments - 2;
	NSCAssert(numberOfArguments == signals.count, @"Wrong number of signals for %@ (expected %lu, got %lu)", NSStringFromSelector(selector), (unsigned long)numberOfArguments, (unsigned long)signals.count);

	@unsafeify(self);
	return [self rac_liftSignals:signals withReducingInvocation:^(RACTuple *arguments) {
		@strongify(self);

		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		invocation.selector = selector;

		NSUInteger index = 2;
		for (id arg in arguments) {
			[invocation rac_setArgument:([RACTupleNil.tupleNil isEqual:arg] ? nil : arg) atIndex:index];
			index++;
		}

		[invocation invokeWithTarget:self];
		return invocation.rac_returnValue;
	}];
}

- (RACSignal *)rac_liftSelector:(SEL)selector withSignals:(RACSignal *)firstSignal, ... {
	NSCParameterAssert(firstSignal != nil);

	NSMutableArray *arguments = [NSMutableArray array];

	va_list args;
	va_start(args, firstSignal);
	for (id currentObject = firstSignal; currentObject != nil; currentObject = va_arg(args, id)) {
		NSCAssert([currentObject isKindOfClass:RACSignal.class], @"Argument %@ is not a RACSignal", currentObject);

		[arguments addObject:currentObject];
	}

	va_end(args);
	return [self rac_liftSelector:selector withSignalsFromArray:arguments];
}

- (RACSignal *)rac_liftBlock:(id)block withSignals:(RACSignal *)firstSignal, ... {
	NSCParameterAssert(firstSignal != nil);

	NSMutableArray *arguments = [NSMutableArray array];

	va_list args;
	va_start(args, firstSignal);
	for (id currentObject = firstSignal; currentObject != nil; currentObject = va_arg(args, id)) {
		[arguments addObject:currentObject];
	}

	va_end(args);
	return [self rac_liftBlock:block withSignalsFromArray:arguments];
}

- (RACSignal *)rac_liftBlock:(id)block withSignalsFromArray:(NSArray *)signals {
	NSCParameterAssert(block != nil);

	return [self rac_liftSignals:signals withReducingInvocation:^(RACTuple *arguments) {
		return [RACBlockTrampoline invokeBlock:block withArguments:arguments];
	}];
}

@end
