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
#import "NSObject+RACPropertySubscribing.h"
#import "RACBlockTrampoline.h"
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import "RACUnit.h"

static RACSignal *RACLiftAndCallBlock(id object, NSArray *args, RACSignal * (^block)(NSArray *));

@implementation NSObject (RACLifting)

- (RACSignal *)rac_liftSignals:(NSArray *)signals withReducingInvocation:(id (^)(RACTuple *))reduceBlock {
	RACMulticastConnection *connection = [[[RACSignal combineLatest:signals] map:reduceBlock] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];

	RACDisposable *disposable = [connection connect];
	[self rac_addDeallocDisposable:disposable];

	return connection.signal;
}

- (RACSignal *)rac_liftSelector:(SEL)selector withObjects:(id)arg, ... {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:methodSignature.numberOfArguments - 2];

	va_list args;
	va_start(args, arg);
	// First two arguments are self and selector.
	for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
		id currentObject = (i == 2 ? arg : va_arg(args, id));
		[arguments addObject:currentObject ?: RACTupleNil.tupleNil];
	}
	va_end(args);

	return [self rac_liftSelector:selector withObjectsFromArray:arguments];
}

- (RACSignal *)rac_liftSelector:(SEL)selector withObjectsFromArray:(NSArray *)args {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSUInteger numberOfArguments = methodSignature.numberOfArguments - 2;
	NSAssert(numberOfArguments == args.count, @"wrong number of args for -%s, expecting %@, received %@", sel_getName(selector), @(numberOfArguments), @(args.count));

	@weakify(self);
	return RACLiftAndCallBlock(self, args, ^(NSArray *arguments) {
		@strongify(self);
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
		invocation.selector = selector;

		for (NSUInteger i = 0; i < arguments.count; i++) {
			[invocation rac_setArgument:[arguments[i] isKindOfClass:RACTupleNil.class] ? nil : arguments[i] atIndex:i + 2];
		}

		[invocation invokeWithTarget:self];
		return [invocation rac_returnValue];
	});
}

- (RACSignal *)rac_liftBlock:(id)block withArguments:(id)arg, ... {
	NSParameterAssert(block != nil);

	NSMutableArray *arguments = [NSMutableArray array];

	va_list args;
	va_start(args, arg);
	for (id currentObject = arg; currentObject != nil; currentObject = va_arg(args, id)) {
		[arguments addObject:currentObject];
	}
	va_end(args);

	return [self rac_liftBlock:block withArgumentsFromArray:arguments];
}

- (RACSignal *)rac_liftBlock:(id)block withArgumentsFromArray:(NSArray *)args {
	NSParameterAssert(block != nil);

	return RACLiftAndCallBlock(self, args, ^(NSArray *arguments) {
		return [RACBlockTrampoline invokeBlock:block withArguments:[RACTuple tupleWithObjectsFromArray:arguments]];
	});
}

@end

static RACSignal *RACLiftAndCallBlock(id object, NSArray *args, RACSignal * (^block)(NSArray *)) {
	NSParameterAssert(block != nil);

	NSMutableArray *signals = [NSMutableArray arrayWithCapacity:args.count];
	NSMutableDictionary *argIndexesBySignal = [NSMutableDictionary dictionaryWithCapacity:args.count];

	for (NSUInteger i = 0; i < args.count; i++) {
		id currentObject = args[i];
		if ([currentObject isKindOfClass:RACSignal.class]) {
			[signals addObject:currentObject];
			argIndexesBySignal[[NSValue valueWithNonretainedObject:currentObject]] = @(i);
		}
	}

	if (signals.count < 1) {
		return block(args);
	} else {
		return [object rac_liftSignals:signals withReducingInvocation:^(RACTuple *xs) {
			NSMutableArray *arguments = [args mutableCopy];
			for (NSUInteger i = 0; i < xs.count; i++) {
				RACSignal *signal = signals[i];
				NSUInteger argIndex = [argIndexesBySignal[[NSValue valueWithNonretainedObject:signal]] unsignedIntegerValue];
				[arguments replaceObjectAtIndex:argIndex withObject:xs[i] ?: RACTupleNil.tupleNil];
			}

			return block(arguments);
		}];
	}
}
