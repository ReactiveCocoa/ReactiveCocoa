//
//  NSObject+RACLifting.m
//  iOSDemo
//
//  Created by Josh Abernathy on 10/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "RACSignal.h"
#import "RACTuple.h"
#import "RACReplaySubject.h"
#import "RACConnectableSignal.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBlockTrampoline.h"
#import "EXTScope.h"
#import "RACUnit.h"
#import "NSInvocation+RACTypeParsing.h"

@implementation NSObject (RACLifting)

- (id<RACSignal>)rac_liftSignals:(NSArray *)signals withReducingInvocation:(id (^)(RACTuple *))reduceBlock {
	RACConnectableSignal *signal = [[[RACSignal combineLatest:signals] map:reduceBlock] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];

	RACDisposable *disposable = [signal connect];
	[self rac_addDeallocDisposable:disposable];

	return signal;
}

- (id<RACSignal>)rac_liftSelector:(SEL)selector withObjects:(id)arg, ... {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	invocation.selector = selector;

	NSMutableArray *signals = [NSMutableArray arrayWithCapacity:methodSignature.numberOfArguments - 2];
	NSMutableDictionary *argIndexesBySignal = [NSMutableDictionary dictionaryWithCapacity:methodSignature.numberOfArguments - 2];

	va_list args;
	va_start(args, arg);
	id currentObject = nil;
	// First two arguments are self and selector.
	for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
		currentObject = (i == 2 ? arg : va_arg(args, id));

		if ([currentObject conformsToProtocol:@protocol(RACSignal)]) {
			[invocation rac_setArgument:nil atIndex:i];
			argIndexesBySignal[[NSValue valueWithNonretainedObject:currentObject]] = @(i);
			[signals addObject:currentObject];
		} else {
			[invocation rac_setArgument:currentObject atIndex:i];
		}
	}
	va_end(args);

	[invocation retainArguments];

	if (signals.count < 1) {
		[invocation invokeWithTarget:self];
		return [invocation rac_returnValue];
	} else {
		@unsafeify(self);
		return [self rac_liftSignals:signals withReducingInvocation:^(RACTuple *xs) {
			@strongify(self);
			for (NSUInteger i = 0; i < xs.count; i++) {
				id<RACSignal> signal = signals[i];
				NSUInteger argIndex = [argIndexesBySignal[[NSValue valueWithNonretainedObject:signal]] unsignedIntegerValue];
				[invocation rac_setArgument:xs[i] atIndex:argIndex];
				[invocation retainArguments];
			}

			[invocation invokeWithTarget:self];

			return [invocation rac_returnValue];
		}];
	}
}

- (id<RACSignal>)rac_liftBlock:(id)block withArguments:(id)arg, ... {
	NSParameterAssert(block != nil);

	NSMutableArray *arguments = [NSMutableArray array];
	NSMutableArray *signals = [NSMutableArray array];
	NSMutableDictionary *argIndexesBySignal = [NSMutableDictionary dictionary];

	va_list args;
	va_start(args, arg);
	NSUInteger i = 0;
	for (id currentObject = arg; currentObject != nil; currentObject = va_arg(args, id)) {
		if ([currentObject conformsToProtocol:@protocol(RACSignal)]) {
			[arguments addObject:RACTupleNil.tupleNil];
			[signals addObject:currentObject];
			argIndexesBySignal[[NSValue valueWithNonretainedObject:currentObject]] = @(i);
		} else {
			[arguments addObject:currentObject];
		}

		i++;
	}
	va_end(args);

	if (signals.count < 1) {
		return [RACBlockTrampoline invokeBlock:block withArguments:arguments];
	} else {
		return [self rac_liftSignals:signals withReducingInvocation:^(RACTuple *xs) {
			for (NSUInteger i = 0; i < xs.count; i++) {
				id<RACSignal> signal = signals[i];
				NSUInteger argIndex = [argIndexesBySignal[[NSValue valueWithNonretainedObject:signal]] unsignedIntegerValue];
				[arguments replaceObjectAtIndex:argIndex withObject:xs[i]];
			}

			return [RACBlockTrampoline invokeBlock:block withArguments:arguments];
		}];
	}
}

@end
