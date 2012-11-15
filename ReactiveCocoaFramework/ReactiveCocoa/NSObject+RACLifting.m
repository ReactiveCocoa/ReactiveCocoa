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

@implementation NSObject (RACLifting)

- (id<RACSubscribable>)rac_liftSubscribables:(NSArray *)subscribables withReducingInvocation:(id (^)(RACTuple *))reduceBlock {
	RACConnectableSubscribable *subscribable = [[[RACSubscribable combineLatest:subscribables] select:reduceBlock] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];

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

		const char *argType = [methodSignature getArgumentTypeAtIndex:i];
		if ([currentObject conformsToProtocol:@protocol(RACSubscribable)]) {
			[self rac_setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)i withObject:nil];
			argIndexesBySubscribable[[NSValue valueWithNonretainedObject:currentObject]] = @(i);
			[subscribables addObject:currentObject];
		} else {
			[self rac_setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)i withObject:currentObject];
		}
	}
	va_end(args);

	[invocation retainArguments];

	if (subscribables.count < 1) {
		[invocation invokeWithTarget:self];
		return [self rac_returnValueForInvocation:invocation methodSignature:methodSignature];
	} else {
		@unsafeify(self);
		return [self rac_liftSubscribables:subscribables withReducingInvocation:^(RACTuple *xs) {
			@strongify(self);
			for (NSUInteger i = 0; i < xs.count; i++) {
				RACSubscribable *subscribable = subscribables[i];
				NSUInteger argIndex = [argIndexesBySubscribable[[NSValue valueWithNonretainedObject:subscribable]] unsignedIntegerValue];
				const char *argType = [methodSignature getArgumentTypeAtIndex:argIndex];
				[self rac_setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)argIndex withObject:xs[i]];
				[invocation retainArguments];
			}

			[invocation invokeWithTarget:self];

			return [self rac_returnValueForInvocation:invocation methodSignature:methodSignature];
		}];
	}
}

- (void)rac_setArgumentForInvocation:(NSInvocation *)invocation type:(const char *)argType atIndex:(NSInteger)index withObject:(id)object {
#define PULL_AND_SET(type, selector) \
	do { \
		type val = [object selector]; \
		[invocation setArgument:&val atIndex:index]; \
	} while(0)

	if (strcmp(argType, "@") == 0 || strcmp(argType, "#") == 0) {
		[invocation setArgument:&object atIndex:index];
	} else if (strcmp(argType, "c") == 0) {
		PULL_AND_SET(char, charValue);
	} else if (strcmp(argType, "i") == 0) {
		PULL_AND_SET(int, intValue);
	} else if (strcmp(argType, "s") == 0) {
		PULL_AND_SET(short, shortValue);
	} else if (strcmp(argType, "l") == 0) {
		PULL_AND_SET(long, longValue);
	} else if (strcmp(argType, "q") == 0) {
		PULL_AND_SET(long long, longLongValue);
	} else if (strcmp(argType, "C") == 0) {
		PULL_AND_SET(unsigned char, unsignedCharValue);
	} else if (strcmp(argType, "I") == 0) {
		PULL_AND_SET(unsigned int, unsignedIntValue);
	} else if (strcmp(argType, "C") == 0) {
		PULL_AND_SET(unsigned short, unsignedShortValue);
	} else if (strcmp(argType, "L") == 0) {
		PULL_AND_SET(unsigned long, unsignedLongValue);
	} else if (strcmp(argType, "Q") == 0) {
		PULL_AND_SET(unsigned long long, unsignedLongLongValue);
	} else if (strcmp(argType, "f") == 0) {
		PULL_AND_SET(float, floatValue);
	} else if (strcmp(argType, "d") == 0) {
		PULL_AND_SET(double, doubleValue);
	} else if (strcmp(argType, "*") == 0) {
		PULL_AND_SET(const char *, UTF8String);
	} else if (argType[0] == '^') {
		PULL_AND_SET(void *, pointerValue);
	} else {
		NSAssert(NO, @"Unknown argument type %s", argType);
	}

#undef PULL_AND_SET
}

- (id)rac_returnValueForInvocation:(NSInvocation *)invocation methodSignature:(NSMethodSignature *)signature {
#define WRAP_AND_RETURN(type) \
	type val = 0; \
	[invocation getReturnValue:&val]; \
	return @(val);

	const char *returnType = signature.methodReturnType;
	if (strcmp(returnType, "@") == 0 || strcmp(returnType, "#") == 0) {
		__autoreleasing id returnObj;
		[invocation getReturnValue:&returnObj];
		return returnObj;
	} else if (strcmp(returnType, "c") == 0) {
		WRAP_AND_RETURN(char);
	} else if (strcmp(returnType, "i") == 0) {
		WRAP_AND_RETURN(int);
	} else if (strcmp(returnType, "s") == 0) {
		WRAP_AND_RETURN(short);
	} else if (strcmp(returnType, "l") == 0) {
		WRAP_AND_RETURN(long);
	} else if (strcmp(returnType, "q") == 0) {
		WRAP_AND_RETURN(long long);
	} else if (strcmp(returnType, "C") == 0) {
		WRAP_AND_RETURN(unsigned char);
	} else if (strcmp(returnType, "I") == 0) {
		WRAP_AND_RETURN(unsigned int);
	} else if (strcmp(returnType, "C") == 0) {
		WRAP_AND_RETURN(unsigned short);
	} else if (strcmp(returnType, "L") == 0) {
		WRAP_AND_RETURN(unsigned long);
	} else if (strcmp(returnType, "Q") == 0) {
		WRAP_AND_RETURN(unsigned long long);
	} else if (strcmp(returnType, "f") == 0) {
		WRAP_AND_RETURN(float);
	} else if (strcmp(returnType, "d") == 0) {
		WRAP_AND_RETURN(double);
	} else if (strcmp(returnType, "*") == 0) {
		WRAP_AND_RETURN(const char *);
	} else if (strcmp(returnType, "v") == 0) {
		return RACUnit.defaultUnit;
	} else if (returnType[0] == '^') {
		const void *pointer = NULL;
		[invocation getReturnValue:&pointer];
		return [NSValue valueWithPointer:pointer];
	} else {
		NSAssert(NO, @"Unknown return type %s", returnType);
	}

	return nil;

#undef WRAP_AND_RETURN
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
