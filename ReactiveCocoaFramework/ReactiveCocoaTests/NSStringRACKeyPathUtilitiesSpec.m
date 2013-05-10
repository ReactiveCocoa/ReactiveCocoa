//
//  NSStringRACKeyPathUtilitiesSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 05/05/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSString+RACKeyPathUtilities.h"

SpecBegin(NSStringRACKeyPathUtilities)

describe(@"-keyPathComponents", ^{
	it(@"should return components in the key path", ^{
		expect(@"self.test.key.path".rac_keyPathComponents).to.equal((@[@"self", @"test", @"key", @"path"]));
	});
	
	it(@"should return nil if given an empty string", ^{
		expect(@"".rac_keyPathComponents).to.beNil();
	});
});

describe(@"-keyPathByDeletingLastKeyPathComponent", ^{
	it(@"should return the parent key path", ^{
		expect(@"grandparent.parent.child".rac_keyPathByDeletingLastKeyPathComponent).to.equal(@"grandparent.parent");
	});
	
	it(@"should return nil if given an empty string", ^{
		expect(@"".rac_keyPathByDeletingLastKeyPathComponent).to.beNil();
	});
	
	it(@"should return nil if given a key path with only one component", ^{
		expect(@"self".rac_keyPathByDeletingLastKeyPathComponent).to.beNil();
	});
});

SpecEnd
