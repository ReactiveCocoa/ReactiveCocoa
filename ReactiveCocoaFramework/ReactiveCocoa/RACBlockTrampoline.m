//
//  RACBlockTrampoline.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 10/21/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACBlockTrampoline.h"
#import "RACTuple.h"

@interface RACBlockTrampoline ()
@property (nonatomic, readonly, copy) id block;
@end

@implementation RACBlockTrampoline

#pragma mark API

- (id)initWithBlock:(id)block {
	self = [super init];
	if (self == nil) return nil;

	_block = [block copy];

	return self;
}

+ (id)invokeBlock:(id)block withArguments:(NSArray *)arguments {
	RACBlockTrampoline *trampoline = [[self alloc] initWithBlock:block];
	return [trampoline invokeWithArguments:arguments];
}

- (id)invokeWithArguments:(NSArray *)arguments {
	SEL selector = [self selectorForArgumentCount:arguments.count];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:selector]];
	invocation.selector = selector;
	invocation.target = self;

	for (NSUInteger i = 0; i < arguments.count; i++) {
		id arg = arguments[i];
		NSInteger argIndex = (NSInteger)(i + 2);
		if ([arg isKindOfClass:RACTupleNil.class]) {
			[invocation setArgument:nil atIndex:argIndex];
		} else {
			[invocation setArgument:&arg atIndex:argIndex];
		}
	}

	[invocation invoke];
	
	id returnVal;
	[invocation getReturnValue:&returnVal];
	return returnVal;
}

- (SEL)selectorForArgumentCount:(NSUInteger)count {
	NSParameterAssert(count > 0);

	NSMutableString *selectorString = [NSMutableString stringWithString:@"performWith"];
	for (NSUInteger i = 0; i < count; i++) {
		[selectorString appendString:@":"];
	}

	SEL selector = NSSelectorFromString(selectorString);
	NSAssert([self respondsToSelector:selector], @"The argument count is too damn high!");
	return selector;
}

- (id)performWith:(id)obj1 {
	id (^block)(id) = self.block;
	return block(obj1);
}

- (id)performWith:(id)obj1 :(id)obj2 {
	id (^block)(id, id) = self.block;
	return block(obj1, obj2);
}

- (id)performWith:(id)obj1 :(id)obj2 :(id)obj3 {
	id (^block)(id, id, id) = self.block;
	return block(obj1, obj2, obj3);
}

- (id)performWith:(id)obj1 :(id)obj2 :(id)obj3 :(id)obj4 {
	id (^block)(id, id, id, id) = self.block;
	return block(obj1, obj2, obj3, obj4);
}

- (id)performWith:(id)obj1 :(id)obj2 :(id)obj3 :(id)obj4 :(id)obj5 {
	id (^block)(id, id, id, id, id) = self.block;
	return block(obj1, obj2, obj3, obj4, obj5);
}

- (id)performWith:(id)obj1 :(id)obj2 :(id)obj3 :(id)obj4 :(id)obj5 :(id)obj6 {
	id (^block)(id, id, id, id, id, id) = self.block;
	return block(obj1, obj2, obj3, obj4, obj5, obj6);
}

- (id)performWith:(id)obj1 :(id)obj2 :(id)obj3 :(id)obj4 :(id)obj5 :(id)obj6 :(id)obj7 {
	id (^block)(id, id, id, id, id, id, id) = self.block;
	return block(obj1, obj2, obj3, obj4, obj5, obj6, obj7);
}

@end
