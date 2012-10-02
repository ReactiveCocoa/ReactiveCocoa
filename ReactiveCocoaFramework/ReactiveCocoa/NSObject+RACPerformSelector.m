//
//  NSObject+RACPerformSelector.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/24/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPerformSelector.h"
#import "RACSubscribable.h"

@implementation NSObject (RACPerformSelector)

- (void)rac_performSelector:(SEL)selector withObjects:(id)arg, ... NS_REQUIRES_NIL_TERMINATION {
	NSMethodSignature *methodSignature = [self methodSignatureForSelector:selector];
	NSAssert2(methodSignature != nil, @"%@ does not respond to %@", self, NSStringFromSelector(selector));

	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	invocation.selector = selector;
	NSMutableArray *subscribeBlocks = [NSMutableArray array];

	va_list args;
    va_start(args, arg);
	// First two arguments are self and selector.
	NSUInteger i = 2;
	__unsafe_unretained id weakSelf = self;
    for (id currentObject = arg; currentObject != nil; currentObject = va_arg(args, id), i++) {
		const char *argType = [methodSignature getArgumentTypeAtIndex:i];
		if ([currentObject conformsToProtocol:@protocol(RACSubscribable)]) {
			// We don't want to subscribe yet because our subscription could
			// immediately yield an object and we'd end up invoking the
			// invocation before all its args have been set. So we accumulate
			// all the subscriptions into blocks and we'll call them after all
			// the setup is done.
			[subscribeBlocks addObject:^{
				id<RACSubscribable> subscribable = (id<RACSubscribable>)currentObject;
				[subscribable subscribeNext:^(id x) {
					NSObject *strongSelf = weakSelf;
					[strongSelf setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)i withObject:x];
					[invocation invokeWithTarget:strongSelf];
				}];
			}];
		} else {
			[self setArgumentForInvocation:invocation type:argType atIndex:(NSInteger)i withObject:currentObject];
		}
    }
    va_end(args);

	for (void (^block)(void) in subscribeBlocks) {
		block();
	}
}

- (void)setArgumentForInvocation:(NSInvocation *)invocation type:(const char *)argType atIndex:(NSInteger)index withObject:(id)object {
	if (strcmp(argType, "@") == 0) {
		[invocation setArgument:&object atIndex:index];
	} else if (strcmp(argType, "c") == 0) {
		char c = [object charValue];
		[invocation setArgument:&c atIndex:index];
	} else if (strcmp(argType, "i") == 0) {
		int i = [object intValue];
		[invocation setArgument:&i atIndex:index];
	} else if (strcmp(argType, "s") == 0) {
		short s = [object shortValue];
		[invocation setArgument:&s atIndex:index];
	} else if (strcmp(argType, "l") == 0) {
		long l = [object longValue];
		[invocation setArgument:&l atIndex:index];
	} else if (strcmp(argType, "q") == 0) {
		long long l = [object longLongValue];
		[invocation setArgument:&l atIndex:index];
	} else if (strcmp(argType, "C") == 0) {
		unsigned char c = [object unsignedCharValue];
		[invocation setArgument:&c atIndex:index];
	} else if (strcmp(argType, "I") == 0) {
		unsigned int i = [object unsignedIntValue];
		[invocation setArgument:&i atIndex:index];
	} else if (strcmp(argType, "C") == 0) {
		unsigned short s = [object unsignedShortValue];
		[invocation setArgument:&s atIndex:index];
	} else if (strcmp(argType, "L") == 0) {
		unsigned long l = [object unsignedLongValue];
		[invocation setArgument:&l atIndex:index];
	} else if (strcmp(argType, "Q") == 0) {
		unsigned long long l = [object unsignedLongLongValue];
		[invocation setArgument:&l atIndex:index];
	} else if (strcmp(argType, "f") == 0) {
		float f = [object floatValue];
		[invocation setArgument:&f atIndex:index];
	} else if (strcmp(argType, "d") == 0) {
		double d = [object doubleValue];
		[invocation setArgument:&d atIndex:index];
	} else if (strcmp(argType, "*") == 0) {
		const char *c = [object UTF8String];
		[invocation setArgument:&c atIndex:index];
	} else if (strcmp(argType, "#") == 0) {
		Class c = [object class];
		[invocation setArgument:&c atIndex:index];
	} else {
		NSAssert1(NO, @"Unknown argument type %s", argType);
	}
}

@end
