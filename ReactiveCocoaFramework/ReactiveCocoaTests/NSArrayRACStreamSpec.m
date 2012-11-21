//
//  NSArrayRACStreamSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 11/10/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "RACStreamExamples.h"
#import "RACUnit.h"

SpecBegin(NSArrayRACStream)

describe(@"<RACStream>", ^{
	id verifyValues = ^(NSArray *array, NSArray *expectedValues) {
		expect(array).notTo.beNil();
    expect(array).to.equal(expectedValues);
	};
  
  // NSArray cannot be infinite, cheat the tests
	NSArray *infiniteArray = @[ RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit, RACUnit.defaultUnit ];
  
	itShouldBehaveLike(RACStreamExamples, @{
                     RACStreamExamplesClass: NSArray.class,
                     RACStreamExamplesVerifyValuesBlock: verifyValues,
                     RACStreamExamplesInfiniteStream: infiniteArray
                     }, nil);
});

SpecEnd
