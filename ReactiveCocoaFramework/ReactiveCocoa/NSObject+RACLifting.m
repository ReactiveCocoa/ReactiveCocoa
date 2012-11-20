//
//  NSObject+RACLifting.m
//  iOSDemo
//
//  Created by Josh Abernathy on 10/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "RACSubscribable.h"
#import "RACTuple.h"
#import "RACReplaySubject.h"
#import "RACConnectableSubscribable.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACBlockTrampoline.h"
#import "EXTScope.h"
#import "RACUnit.h"
#import "NSInvocation+RACTypeParsing.h"

@implementation NSObject (RACLifting)

- (id<RACSubscribable>)rac_liftSubscribables:(NSArray *)subscribables withReducingInvocation:(id (^)(RACTuple *))reduceBlock {
	RACConnectableSubscribable *subscribable = [[[RACSubscribable combineLatest:subscribables] map:reduceBlock] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];

	RACDisposable *disposable = [subscribable connect];
	[self rac_addDeallocDisposable:disposable];

	return subscribable;
}

- (id<RACSubscribable>)rac_liftSelector:(SEL)selector withObjects:(id)arg, ... {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	invocation.selector = selector;

	NSMutableArray *subscribables = [NSMutableArray arrayWithCapacity:methodSignature.numberOfArguments - 2];
	NSMutableDictionary *argIndexesBySubscribable = [NSMutableDictionary dictionaryWithCapacity:methodSignature.numberOfArguments - 2];

	va_list args;
	va_start(args, arg);
	id currentObject = nil;
	// First two arguments are self and selector.
	for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
		currentObject = (i == 2 ? arg : va_arg(args, id));

		if ([currentObject conformsToProtocol:@protocol(RACSubscribable)]) {
			[invocation rac_setArgument:nil atIndex:i];
			argIndexesBySubscribable[[NSValue valueWithNonretainedObject:currentObject]] = @(i);
			[subscribables addObject:currentObject];
		} else {
			[invocation rac_setArgument:currentObject atIndex:i];
		}
	}
	va_end(args);

	[invocation retainArguments];

	if (subscribables.count < 1) {
		[invocation invokeWithTarget:self];
		return [invocation rac_returnValue];
	} else {
		@unsafeify(self);
		return [self rac_liftSubscribables:subscribables withReducingInvocation:^(RACTuple *xs) {
			@strongify(self);
			for (NSUInteger i = 0; i < xs.count; i++) {
				RACSubscribable *subscribable = subscribables[i];
				NSUInteger argIndex = [argIndexesBySubscribable[[NSValue valueWithNonretainedObject:subscribable]] unsignedIntegerValue];
				[invocation rac_setArgument:xs[i] atIndex:argIndex];
				[invocation retainArguments];
			}

			[invocation invokeWithTarget:self];

			return [invocation rac_returnValue];
		}];
	}
}

- (id<RACSubscribable>)rac_liftBlock:(id)block withArguments:(id)arg, ... {
	NSParameterAssert(block != nil);

	NSMutableArray *arguments = [NSMutableArray array];
	NSMutableArray *subscribables = [NSMutableArray array];
	NSMutableDictionary *argIndexesBySubscribable = [NSMutableDictionary dictionary];

	va_list args;
	va_start(args, arg);
	NSUInteger i = 0;
	for (id currentObject = arg; currentObject != nil; currentObject = va_arg(args, id)) {
		if ([currentObject conformsToProtocol:@protocol(RACSubscribable)]) {
			[arguments addObject:RACTupleNil.tupleNil];
			[subscribables addObject:currentObject];
			argIndexesBySubscribable[[NSValue valueWithNonretainedObject:currentObject]] = @(i);
		} else {
			[arguments addObject:currentObject];
		}

		i++;
	}
	va_end(args);

	if (subscribables.count < 1) {
		return [RACBlockTrampoline invokeBlock:block withArguments:arguments];
	} else {
		return [self rac_liftSubscribables:subscribables withReducingInvocation:^(RACTuple *xs) {
			for (NSUInteger i = 0; i < xs.count; i++) {
				RACSubscribable *subscribable = subscribables[i];
				NSUInteger argIndex = [argIndexesBySubscribable[[NSValue valueWithNonretainedObject:subscribable]] unsignedIntegerValue];
				[arguments replaceObjectAtIndex:argIndex withObject:xs[i]];
			}

			return [RACBlockTrampoline invokeBlock:block withArguments:arguments];
		}];
	}
}

@end
