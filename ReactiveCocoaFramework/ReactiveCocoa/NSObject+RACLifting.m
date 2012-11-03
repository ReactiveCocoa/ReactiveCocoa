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
	[invocation retainArguments];
	invocation.selector = selector;

	NSMutableArray *subscribables = [NSMutableArray arrayWithCapacity:methodSignature.numberOfArguments - 2];

	va_list args;
	va_start(args, arg);
	id currentObject = nil;
	// First two arguments are self and selector.
	for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
		currentObject = (i == 2 ? arg : va_arg(args, id));

		const char *argType = [methodSignature getArgumentTypeAtIndex:i];
		if ([currentObject conformsToProtocol:@protocol(RACSubscribable)]) {
			[self rac_setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)i withObject:nil];
			[subscribables addObject:currentObject];
		} else {
			[self rac_setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)i withObject:currentObject];
		}
	}
	va_end(args);

	__unsafe_unretained id weakSelf = self;
	return [self rac_liftSubscribables:subscribables withReducingInvocation:^(RACTuple *xs) {
		NSObject *strongSelf = weakSelf;
		for (NSUInteger i = 0; i < xs.count; i++) {
			// First two arguments are self and selector.
			NSUInteger argIndex = i + 2;
			const char *argType = [methodSignature getArgumentTypeAtIndex:argIndex];
			[strongSelf rac_setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)argIndex withObject:xs[i]];
		}

		[invocation invokeWithTarget:strongSelf];

		return [strongSelf rac_returnValueForInvocation:invocation methodSignature:methodSignature];
	}];
}

- (void)rac_setArgumentForInvocation:(NSInvocation *)invocation type:(const char *)argType atIndex:(NSInteger)index withObject:(id)object {
#define pullAndSet(type, selector) \
	type val = [object selector]; \
	[invocation setArgument:&val atIndex:index];

	if (strcmp(argType, "@") == 0 || strcmp(argType, "#") == 0) {
		[invocation setArgument:&object atIndex:index];
	} else if (strcmp(argType, "c") == 0) {
		pullAndSet(char, charValue);
	} else if (strcmp(argType, "i") == 0) {
		pullAndSet(int, intValue);
	} else if (strcmp(argType, "s") == 0) {
		pullAndSet(short, shortValue);
	} else if (strcmp(argType, "l") == 0) {
		pullAndSet(long, longValue);
	} else if (strcmp(argType, "q") == 0) {
		pullAndSet(long long, longLongValue);
	} else if (strcmp(argType, "C") == 0) {
		pullAndSet(unsigned char, unsignedCharValue);
	} else if (strcmp(argType, "I") == 0) {
		pullAndSet(unsigned int, unsignedIntValue);
	} else if (strcmp(argType, "C") == 0) {
		pullAndSet(unsigned short, unsignedShortValue);
	} else if (strcmp(argType, "L") == 0) {
		pullAndSet(unsigned long, unsignedLongValue);
	} else if (strcmp(argType, "Q") == 0) {
		pullAndSet(unsigned long long, unsignedLongLongValue);
	} else if (strcmp(argType, "f") == 0) {
		pullAndSet(float, floatValue);
	} else if (strcmp(argType, "d") == 0) {
		pullAndSet(double, doubleValue);
	} else if (strcmp(argType, "*") == 0) {
		pullAndSet(const char *, UTF8String);
	} else if (argType[0] == '^') {
		pullAndSet(void *, pointerValue);
	} else {
		NSAssert(NO, @"Unknown argument type %s", argType);
	}

#undef pullAndSet
}

- (id)rac_returnValueForInvocation:(NSInvocation *)invocation methodSignature:(NSMethodSignature *)signature {
#define wrapAndReturn(type) \
	type val = 0; \
	[invocation getReturnValue:&val]; \
	return @(val);

	const char *returnType = signature.methodReturnType;
	if (strcmp(returnType, "@") == 0 || strcmp(returnType, "#") == 0) {
		__autoreleasing id returnObj;
		[invocation getReturnValue:&returnObj];
		return returnObj;
	} else if (strcmp(returnType, "c") == 0) {
		wrapAndReturn(char);
	} else if (strcmp(returnType, "i") == 0) {
		wrapAndReturn(int);
	} else if (strcmp(returnType, "s") == 0) {
		wrapAndReturn(short);
	} else if (strcmp(returnType, "l") == 0) {
		wrapAndReturn(long);
	} else if (strcmp(returnType, "q") == 0) {
		wrapAndReturn(long long);
	} else if (strcmp(returnType, "C") == 0) {
		wrapAndReturn(unsigned char);
	} else if (strcmp(returnType, "I") == 0) {
		wrapAndReturn(unsigned int);
	} else if (strcmp(returnType, "C") == 0) {
		wrapAndReturn(unsigned short);
	} else if (strcmp(returnType, "L") == 0) {
		wrapAndReturn(unsigned long);
	} else if (strcmp(returnType, "Q") == 0) {
		wrapAndReturn(unsigned long long);
	} else if (strcmp(returnType, "f") == 0) {
		wrapAndReturn(float);
	} else if (strcmp(returnType, "d") == 0) {
		wrapAndReturn(double);
	} else if (strcmp(returnType, "*") == 0) {
		wrapAndReturn(const char *);
	} else if (strcmp(returnType, "v") == 0) {
		return nil;
	} else if (returnType[0] == '^') {
		const void *pointer = NULL;
		[invocation getReturnValue:&pointer];
		return [NSValue valueWithPointer:pointer];
	} else {
		NSAssert(NO, @"Unknown return type %s", returnType);
	}

	return nil;

#undef wrapAndReturn
}

- (id<RACSubscribable>)rac_liftBlock:(id)block withArguments:(id)arg, ... {
	NSParameterAssert(block != nil);

	NSMutableArray *arguments = [NSMutableArray array];
	NSMutableArray *subscribables = [NSMutableArray array];

	va_list args;
    va_start(args, arg);
    for (id currentObject = arg; currentObject != nil; currentObject = va_arg(args, id)) {
        if ([currentObject conformsToProtocol:@protocol(RACSubscribable)]) {
			[arguments addObject:RACTupleNil.tupleNil];
			[subscribables addObject:currentObject];
		} else {
			[arguments addObject:currentObject];
		}
    }
    va_end(args);

	return [self rac_liftSubscribables:subscribables withReducingInvocation:^(RACTuple *xs) {
		for (NSUInteger i = 0; i < xs.count; i++) {
			[arguments replaceObjectAtIndex:i withObject:xs[i]];
		}

		return [RACBlockTrampoline invokeBlock:block withArguments:arguments];
	}];
}

@end
