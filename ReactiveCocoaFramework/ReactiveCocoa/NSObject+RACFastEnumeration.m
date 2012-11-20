//
//  NSObject+RACFastEnumeration.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 3/27/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACFastEnumeration.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSObject (RACFastEnumeration)

- (RACSignal *)rac_toSignal {
	NSParameterAssert([self conformsToProtocol:@protocol(NSFastEnumeration)]);
	
	return [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
		id<NSFastEnumeration> fastEnumerable = (id<NSFastEnumeration>)self;
		for (id object in fastEnumerable) {
			[subscriber sendNext:object];
		}
		
		[subscriber sendCompleted];
		
		return nil;
	}];
}

@end
