//
//  RACSubclassObject.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/18/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSubclassObject.h"
#import "RACScheduler.h"

@implementation RACSubclassObject

- (void)forwardInvocation:(NSInvocation *)invocation {
	self.forwardedSelector = invocation.selector;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
	NSParameterAssert(selector != NULL);

	NSMethodSignature *signature = [super methodSignatureForSelector:selector];
	if (signature != nil) return signature;

	return [super methodSignatureForSelector:@selector(description)];
}

- (NSString *)combineObjectValue:(id)objectValue andIntegerValue:(NSInteger)integerValue {
	NSString *appended = [[objectValue description] stringByAppendingString:@"SUBCLASS"];
	return [super combineObjectValue:appended andIntegerValue:integerValue];
}

- (void)setObjectValue:(id)objectValue andSecondObjectValue:(id)secondObjectValue {
	[RACScheduler.currentScheduler schedule:^{
		[super setObjectValue:objectValue andSecondObjectValue:secondObjectValue];
	}];
}

@end
