//
//  NSObject+RACOperations.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 4/6/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACOperations.h"
#import "NSObject+RACPropertySubscribing.h"
#import "NSObject+RACSubscribable.h"
#import "RACSubscribable.h"
#import "RACSubscribable+Operations.h"
#import "RACSubscriber.h"
#import "NSObject+RACFastEnumeration.h"
#import "RACTuple.h"
#import "NSArray+RACExtensions.h"


@implementation NSObject (RACOperations)

- (RACSubscribable *)rac_whenAny:(NSArray *)keyPaths reduce:(id (^)(RACTuple *xs))reduceBlock {
	NSParameterAssert(keyPaths != nil);
	NSParameterAssert(reduceBlock != NULL);
	
	__block __unsafe_unretained id weakSelf = self;
	return [RACSubscribable createSubscribable:^RACDisposable *(id<RACSubscriber> observer) {
		NSObject *strongSelf = weakSelf;
		
		RACTuple * (^currentValues)(void) = ^{
			NSMutableArray *values = [NSMutableArray arrayWithCapacity:keyPaths.count];
			for(NSString *keyPath in keyPaths) {
				[values addObject:[strongSelf valueForKeyPath:keyPath] ? : [RACTupleNil tupleNil]];
			}
			
			return [RACTuple tupleWithObjectsFromArray:values];
		};
		
		[observer sendNext:reduceBlock(currentValues())];
		
		NSArray *subscribables = [keyPaths rac_select:^(NSString *keyPath) {
			return [strongSelf RACSubscribableForKeyPath:keyPath onObject:strongSelf];
		}];
		
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
