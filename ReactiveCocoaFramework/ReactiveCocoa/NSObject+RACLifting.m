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
#import "RACMulticastConnection.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"
#import "RACUnit.h"

static RACSignal *RACLiftAndCallBlock(id object, NSArray *args, RACSignal * (^block)(NSArray *));

// A proxy object that lifts messages to its target to operate on signals.
// Messages sent to an RACLiftProxy object will be lifted according to the same
// rules as -rac_liftSelector:withObjects:, with the exception that messages
// returning a non-object type are not possible.
@interface RACLiftProxy : NSProxy
- (id)initWithTarget:(NSObject *)target;
@end

@implementation NSObject (RACLifting)

- (RACSignal *)rac_liftSignals:(NSArray *)signals withReducingInvocation:(id (^)(RACTuple *))reduceBlock {
	RACMulticastConnection *connection = [[[RACSignal combineLatest:signals] map:reduceBlock] multicast:[RACReplaySubject replaySubjectWithCapacity:1]];

	RACDisposable *disposable = [connection connect];
	[self rac_addDeallocDisposable:disposable];

	return connection.signal;
}

- (RACSignal *)rac_liftSelector:(SEL)selector withObjectsFromArray:(NSArray *)args {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSCAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSUInteger numberOfArguments __attribute__((unused)) = methodSignature.numberOfArguments - 2;
	NSCAssert(numberOfArguments == args.count, @"wrong number of args for -%@, expecting %lu, received %lu", NSStringFromSelector(selector), (unsigned long)numberOfArguments, (unsigned long)args.count);

	@unsafeify(self);
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

- (RACSignal *)rac_liftSelector:(SEL)selector withObjects:(id)arg, ... {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSCAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

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

- (RACSignal *)rac_liftBlock:(id)block withArguments:(id)arg, ... {
	NSCParameterAssert(block != nil);

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
	NSCParameterAssert(block != nil);

	return RACLiftAndCallBlock(self, args, ^(NSArray *arguments) {
		return [RACBlockTrampoline invokeBlock:block withArguments:[RACTuple tupleWithObjectsFromArray:arguments]];
	});
}

- (instancetype)rac_lift {
	return (id)[[RACLiftProxy alloc] initWithTarget:self];
}

@end

static RACSignal *RACLiftAndCallBlock(id object, NSArray *args, RACSignal * (^block)(NSArray *)) {
	NSCParameterAssert(block != nil);

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
		NSMutableArray *arguments = [args mutableCopy];
		return [object rac_liftSignals:signals withReducingInvocation:^(RACTuple *xs) {
			for (NSUInteger i = 0; i < xs.count; i++) {
				RACSignal *signal = signals[i];
				NSUInteger argIndex = [argIndexesBySignal[[NSValue valueWithNonretainedObject:signal]] unsignedIntegerValue];
				[arguments replaceObjectAtIndex:argIndex withObject:xs[i] ?: RACTupleNil.tupleNil];
			}

			return block(arguments);
		}];
	}
}

@implementation RACLiftProxy {
	NSObject *_target;
}

- (id)initWithTarget:(id)target {
	_target = target;
	return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
	return [_target methodSignatureForSelector:aSelector] ?: [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
	NSMethodSignature *signature = anInvocation.methodSignature;
	NSUInteger argumentsCount = signature.numberOfArguments - 2;

	NSMutableArray *arguments = [NSMutableArray arrayWithCapacity:argumentsCount];

	// First two arguments are self and selector.
	for (NSUInteger i = 2; i < signature.numberOfArguments; i++) {
		id argument = [anInvocation rac_argumentAtIndex:i];
		[arguments addObject:argument ?: RACTupleNil.tupleNil];
	}

	__autoreleasing id returnValue = [_target rac_liftSelector:anInvocation.selector withObjectsFromArray:arguments];

	const char *returnType = signature.methodReturnType;
	if (signature.methodReturnLength > 0) {
		if (strcmp(returnType, "@") == 0 || strcmp(returnType, "#") == 0) {
			[anInvocation setReturnValue:&returnValue];
		} else {
			NSCAssert(NO, @"-rac_lift may only lift messages which return void or object types; %@ returns %s", NSStringFromSelector(anInvocation.selector), returnType);
		}
	}
}

@end
