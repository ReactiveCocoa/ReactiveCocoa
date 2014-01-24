//
//  RACCollectionMutationSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-01-23.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

#import "NSArray+RACSupport.h"
#import "NSSet+RACSupport.h"
#import "RACMinusMutation.h"
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

SpecEnd
