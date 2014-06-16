//
//  RACCollectionMutationSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-23.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "NSArray+RACSupport.h"
#import "NSSet+RACSupport.h"
#import "RACInsertionMutation.h"
#import "RACMinusMutation.h"
#import "RACMoveMutation.h"
#import "RACRemovalMutation.h"
#import "RACReplacementMutation.h"
#import "RACSettingMutation.h"
#import "RACUnionMutation.h"

SpecBegin(RACCollectionMutation)

__block NSMutableArray *valueArray;
__block NSMutableSet *valueSet;

beforeEach(^{
	valueArray = [NSMutableArray arrayWithObjects:@"foo", @"bar", @"fuzz", @"buzz", nil];
	valueSet = [NSMutableSet setWithArray:valueArray];
});

describe(@"RACSettingMutation", ^{
	__block RACSettingMutation *mutation;

	beforeEach(^{
		NSArray *objects = @[ @YES, @NO ];

		mutation = [[RACSettingMutation alloc] initWithObjects:objects];
		expect(mutation).notTo.beNil();
		expect(mutation.addedObjects).to.equal(objects);
	});

	it(@"should replace all objects in an ordered collection", ^{
		[mutation mutateOrderedCollection:valueArray];
		expect(valueArray).to.equal(mutation.addedObjects);
	});

	it(@"should replace all objects in an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal([NSSet setWithArray:mutation.addedObjects]);
	});
});

describe(@"RACUnionMutation", ^{
	__block RACUnionMutation *mutation;

	beforeEach(^{
		NSArray *objects = @[ @"foo", @"fizz" ];

		mutation = [[RACUnionMutation alloc] initWithObjects:objects];
		expect(mutation).notTo.beNil();
		expect(mutation.addedObjects).to.equal(objects);
	});

	it(@"should append objects in an ordered collection", ^{
		[mutation mutateCollection:valueArray];
		expect(valueArray).to.equal((@[ @"foo", @"bar", @"fuzz", @"buzz", @"foo", @"fizz" ]));
	});

	it(@"should union objects in an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal(([NSSet setWithArray:@[ @"foo", @"bar", @"fuzz", @"buzz", @"fizz" ]]));
	});
});

describe(@"RACMinusMutation", ^{
	__block RACMinusMutation *mutation;

	beforeEach(^{
		NSArray *objects = @[ @"foo", @"fizz" ];

		mutation = [[RACMinusMutation alloc] initWithObjects:objects];
		expect(mutation).notTo.beNil();
		expect(mutation.removedObjects).to.equal(objects);
	});

	it(@"should find and remove objects in an ordered collection", ^{
		[mutation mutateCollection:valueArray];
		expect(valueArray).to.equal((@[ @"bar", @"fuzz", @"buzz" ]));
	});

	it(@"should remove objects in an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal(([NSSet setWithArray:@[ @"bar", @"fuzz", @"buzz" ]]));
	});
});

describe(@"RACInsertionMutation", ^{
	__block RACInsertionMutation *mutation;

	beforeEach(^{
		NSArray *objects = @[ @"foo", @"fizz" ];
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(2, 2)];

		mutation = [[RACInsertionMutation alloc] initWithObjects:objects indexes:indexes];
		expect(mutation).notTo.beNil();
		expect(mutation.addedObjects).to.equal(objects);
		expect(mutation.indexes).to.equal(indexes);
	});

	it(@"should insert objects in an ordered collection", ^{
		[mutation mutateOrderedCollection:valueArray];
		expect(valueArray).to.equal((@[ @"foo", @"bar", @"foo", @"fizz", @"fuzz", @"buzz" ]));
	});

	it(@"should union objects in an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal(([NSSet setWithArray:@[ @"foo", @"bar", @"fuzz", @"buzz", @"fizz" ]]));
	});
});

describe(@"RACRemovalMutation", ^{
	__block RACRemovalMutation *mutation;

	beforeEach(^{
		NSArray *objects = @[ @"bar", @"buzz" ];
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)];

		mutation = [[RACRemovalMutation alloc] initWithObjects:objects indexes:indexes];
		expect(mutation).notTo.beNil();
		expect(mutation.removedObjects).to.equal(objects);
		expect(mutation.indexes).to.equal(indexes);
	});

	it(@"should remove objects by index in an ordered collection", ^{
		[mutation mutateOrderedCollection:valueArray];

		// `buzz` remains because we were deleting by index, not object content.
		expect(valueArray).to.equal((@[ @"foo", @"buzz" ]));
	});

	it(@"should remove objects by equality in an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal(([NSSet setWithArray:@[ @"foo", @"fuzz" ]]));
	});
});

describe(@"RACMoveMutation", ^{
	__block RACMoveMutation *mutation;

	beforeEach(^{
		NSUInteger fromIndex = 0;
		NSUInteger toIndex = 2;

		mutation = [[RACMoveMutation alloc] initWithFromIndex:fromIndex toIndex:toIndex];
		expect(mutation).notTo.beNil();
		expect(mutation.fromIndex).to.equal(fromIndex);
		expect(mutation.toIndex).to.equal(toIndex);
	});

	it(@"should move an object in an ordered collection", ^{
		[mutation mutateOrderedCollection:valueArray];
		expect(valueArray).to.equal((@[ @"bar", @"fuzz", @"foo", @"buzz" ]));
	});

	it(@"should not modify an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal([NSSet setWithArray:valueArray]);
	});
});

describe(@"RACReplacementMutation", ^{
	__block RACReplacementMutation *mutation;

	beforeEach(^{
		NSArray *removedObjects = @[ @"bar", @"buzz" ];
		NSArray *addedObjects = @[ @"foo", @"fizz" ];
		NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, 2)];

		mutation = [[RACReplacementMutation alloc] initWithRemovedObjects:removedObjects addedObjects:addedObjects indexes:indexes];
		expect(mutation).notTo.beNil();
		expect(mutation.addedObjects).to.equal(addedObjects);
		expect(mutation.removedObjects).to.equal(removedObjects);
		expect(mutation.indexes).to.equal(indexes);
	});

	it(@"should replace objects by index in an ordered collection", ^{
		[mutation mutateOrderedCollection:valueArray];

		// `fuzz` is deleted, and `buzz` remains, because we were replacing by
		// index, not object content.
		expect(valueArray).to.equal((@[ @"foo", @"foo", @"fizz", @"buzz" ]));
	});

	it(@"should replace objects by equality in an unordered collection", ^{
		[mutation mutateCollection:valueSet];
		expect(valueSet).to.equal(([NSSet setWithArray:@[ @"foo", @"fuzz", @"fizz" ]]));
	});
});

SpecEnd
