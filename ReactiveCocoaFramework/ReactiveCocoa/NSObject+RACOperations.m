//
//  NSObject+RACOperations.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NSObject+RACOperations.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACSubscribable.h"
#import "RACSubscribable.h"
#import "RACSubscribable+Operations.h"
#import "EXTNil.h"
#import "RACSubscriber.h"


@implementation NSObject (RACOperations)

- (RACSubscribable *)rac_whenAny:(NSArray *)keyPaths reduce:(id (^)(NSArray *xs))reduceBlock {
	NSParameterAssert(keyPaths != nil);
	NSParameterAssert(reduceBlock != NULL);
	
	__block __unsafe_unretained id weakSelf = self;
	return [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		NSObject *strongSelf = weakSelf;
		
		NSArray * (^currentValues)(void) = ^{
			NSMutableArray *values = [NSMutableArray arrayWithCapacity:keyPaths.count];
			for(NSString *keyPath in keyPaths) {
				[values addObject:[strongSelf valueForKeyPath:keyPath] ? : [EXTNil null]];
			}
			
			return values;
		};
		
		NSMutableArray *subscribables = [NSMutableArray arrayWithCapacity:keyPaths.count];
		for(NSString *keyPath in keyPaths) {
			[subscribables addObject:[self RACSubscribableForKeyPath:keyPath onObject:self]];
		}
		
		[observer sendNext:reduceBlock(currentValues())];
		
		return [[RACSubscribable merge:subscribables] subscribeNext:^(id x) {
			[observer sendNext:reduceBlock(currentValues())];
		} error:^(NSError *error) {
			[observer sendError:error];
		} completed:^{
			[observer sendCompleted];
		}];
	}];
}

@end
