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


@implementation NSObject (RACOperations)

- (RACSubscribable *)rac_whenAny:(NSArray *)keyPaths reduce:(id (^)(NSArray *xs))reduceBlock {
	NSParameterAssert(keyPaths != nil);
	NSParameterAssert(reduceBlock != NULL);
	
	NSMutableArray *subscribables = [NSMutableArray arrayWithCapacity:keyPaths.count];
	for(NSString *keyPath in keyPaths) {
		[subscribables addObject:[[self RACSubscribableForKeyPath:keyPath onObject:self] distinctUntilChanged]];
	}
	
	__block __unsafe_unretained id weakSelf = self;
	return [[RACSubscribable merge:subscribables] select:^(id x) {
		NSObject *strongSelf = weakSelf;
		NSMutableArray *values = [NSMutableArray arrayWithCapacity:keyPaths.count];
		for(NSString *keyPath in keyPaths) {
			[values addObject:[strongSelf valueForKeyPath:keyPath] ? : [EXTNil null]];
		}
		
		return reduceBlock(values);
	}];
}

@end
