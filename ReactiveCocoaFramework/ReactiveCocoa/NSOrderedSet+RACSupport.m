//
//  NSOrderedSet+RACSupport.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-10-29.
//  Copyright (c) 2012 GitHub. All rights reserved.
//

#import "NSOrderedSet+RACSupport.h"
#import "NSArray+RACSupport.h"
#import "NSObject+RACDescription.h"
#import "RACCompoundDisposable.h"
#import "RACSignal.h"
#import "RACSubscriber.h"

@implementation NSOrderedSet (RACSupport)

- (RACSignal *)rac_signal {
	NSOrderedSet *collection = [self copy];

	return [[RACSignal create:^(id<RACSubscriber> subscriber) {
		for (id obj in collection) {
			[subscriber sendNext:obj];

			if (subscriber.disposable.disposed) return;
		}

		[subscriber sendCompleted];
	}] setNameWithFormat:@"%@ -rac_signal", self.rac_description];
}

@end

@implementation NSMutableOrderedSet (RACCollectionSupport)

- (void)rac_addObjects:(NSArray *)objects {
	[self addObjectsFromArray:objects];
}

- (void)rac_removeObjects:(NSArray *)objects {
	[self removeObjectsInArray:objects];
}

- (void)rac_replaceAllObjects:(NSArray *)objects {
	[self removeAllObjects];
	[self addObjectsFromArray:objects];
}

- (void)rac_insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)indexSet {
	[self insertObjects:objects atIndexes:indexSet];
}

- (void)rac_removeObjectsAtIndexes:(NSIndexSet *)indexSet {
	[self removeObjectsAtIndexes:indexSet];
}

- (void)rac_replaceObjectsAtIndexes:(NSIndexSet *)indexSet withObjects:(NSArray *)objects {
	[self replaceObjectsAtIndexes:indexSet withObjects:objects];
}

- (void)rac_moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex {
	[self moveObjectsAtIndexes:[NSIndexSet indexSetWithIndex:fromIndex] toIndex:toIndex];
}

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wdeprecated-implementations"

@implementation NSOrderedSet (RACSupportDeprecated)

- (RACSequence *)rac_sequence {
	// TODO: First class support for ordered set sequences.
	return self.array.rac_sequence;
}

@end

#pragma clang diagnostic pop
