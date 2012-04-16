//
//  NSObject+RACFastEnumeration.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/27/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACFastEnumeration.h"
#import "RACSubscribable.h"
#import "RACSubscriber.h"


@implementation NSObject (RACFastEnumeration)

- (RACSubscribable *)toSubscribable {
	NSParameterAssert([self conformsToProtocol:@protocol(NSFastEnumeration)]);
	
	return [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		id<NSFastEnumeration> fastEnumerable = (id<NSFastEnumeration>) self;
		for(id object in fastEnumerable) {
			[observer sendNext:object];
		}
		
		[observer sendCompleted];
		
		return nil;
	}];
}

@end
