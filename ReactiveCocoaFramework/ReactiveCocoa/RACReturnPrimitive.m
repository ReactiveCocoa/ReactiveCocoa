//
//  RACReturnPrimitive.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RACReturnPrimitive.h"
#import "RACSequence+Private.h"

@interface RACReturnPrimitive ()
@property (nonatomic, strong) id returnValue;
@end


@implementation RACReturnPrimitive


#pragma mark RACObservable

- (id)subscribe:(RACObserver *)observer {
	[super subscribe:observer];
	
	self.value = self.returnValue;
	[self sendCompletedToAllObservers];
	
	return self;
}


#pragma mark API

@synthesize returnValue;

+ (id)primitiveWithReturn:(id)returnValue {
	RACReturnPrimitive *primitive = [self value];
	primitive.returnValue = returnValue;
	return primitive;
}

@end
