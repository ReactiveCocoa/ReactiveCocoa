//
//  NSObject+RACLifting.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/13/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACLifting.h"
#import "EXTScope.h"
#import "NSInvocation+RACTypeParsing.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACSignal+Operations.h"
#import "RACTuple.h"

@implementation NSObject (RACLifting)

- (RACSignal *)rac_liftSelector:(SEL)selector withSignalOfArguments:(RACSignal *)arguments {
	NSCParameterAssert(selector != NULL);
	NSCParameterAssert(arguments != nil);
	
	@unsafeify(self);
	
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSCAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));
	
	return [[[[arguments
		takeUntil:self.rac_willDeallocSignal]
		map:^(RACTuple *arguments) {
			@strongify(self);
			
			NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
			invocation.selector = selector;
			invocation.rac_argumentsTuple = arguments;
			[invocation invokeWithTarget:self];
			
			return invocation.rac_returnValue;
		}]
		replayLast]
		setNameWithFormat:@"%@ -rac_liftSelector: %s withSignalsOfArguments: %@", self.rac_description, sel_getName(selector), arguments];
}

- (RACSignal *)rac_liftSelector:(SEL)selector withSignalsFromArray:(NSArray *)signals {
	NSCParameterAssert(signals != nil);
	NSCParameterAssert(signals.count > 0);

	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSCAssert(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSUInteger numberOfArguments __attribute__((unused)) = methodSignature.numberOfArguments - 2;
	NSCAssert(numberOfArguments == signals.count, @"Wrong number of signals for %@ (expected %lu, got %lu)", NSStringFromSelector(selector), (unsigned long)numberOfArguments, (unsigned long)signals.count);

	return [[self
		rac_liftSelector:selector withSignalOfArguments:[RACSignal combineLatest:signals]]
		setNameWithFormat:@"%@ -rac_liftSelector: %s withSignalsFromArray: %@", self.rac_description, sel_getName(selector), signals];
}

- (RACSignal *)rac_liftSelector:(SEL)selector withSignals:(RACSignal *)firstSignal, ... {
	NSCParameterAssert(firstSignal != nil);

	NSMutableArray *signals = [NSMutableArray array];

	va_list args;
	va_start(args, firstSignal);
	for (id currentSignal = firstSignal; currentSignal != nil; currentSignal = va_arg(args, id)) {
		NSCAssert([currentSignal isKindOfClass:RACSignal.class], @"Argument %@ is not a RACSignal", currentSignal);

		[signals addObject:currentSignal];
	}
	va_end(args);

	return [[self
		rac_liftSelector:selector withSignalsFromArray:signals]
		setNameWithFormat:@"%@ -rac_liftSelector: %s withSignals: %@", self.rac_description, sel_getName(selector), signals];
}

@end

@implementation NSObject (RACLiftingDeprecated)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

static NSArray *RACMapArgumentsToSignals(NSArray *args) {
	NSMutableArray *mappedArgs = [NSMutableArray array];
	for (id arg in args) {
		if ([arg isEqual:RACTupleNil.tupleNil]) {
			[mappedArgs addObject:[RACSignal return:nil]];
		} else if ([arg isKindOfClass:RACSignal.class]) {
			[mappedArgs addObject:arg];
		} else {
			[mappedArgs addObject:[RACSignal return:arg]];
		}
	}

	return mappedArgs;
}

- (RACSignal *)rac_liftSelector:(SEL)selector withObjects:(id)arg, ... {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSMutableArray *arguments = [NSMutableArray array];

	va_list args;
	va_start(args, arg);
	for (NSUInteger i = 2; i < methodSignature.numberOfArguments; i++) {
		id currentObject = (i == 2 ? arg : va_arg(args, id));
		[arguments addObject:currentObject ?: RACTupleNil.tupleNil];
	}

	va_end(args);
	return [self rac_liftSelector:selector withObjectsFromArray:arguments];
}

- (RACSignal *)rac_liftSelector:(SEL)selector withObjectsFromArray:(NSArray *)args {
	return [self rac_liftSelector:selector withSignalsFromArray:RACMapArgumentsToSignals(args)];
}

- (RACSignal *)rac_liftBlock:(id)block withArguments:(id)arg, ... {
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
	return [[[[RACSignal
		combineLatest:RACMapArgumentsToSignals(args)]
		reduceEach:block]
		takeUntil:self.rac_willDeallocSignal]
		replayLast];
}

#pragma clang diagnostic pop

@end
