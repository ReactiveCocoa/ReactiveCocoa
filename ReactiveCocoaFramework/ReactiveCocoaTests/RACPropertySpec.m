//
//  RACPropertySpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
#import "RACPropertyExamples.h"

SpecBegin(RACProperty)

describe(@"RACProperty", ^{
	itShouldBehaveLike(RACPropertyExamples, [^{ return [RACProperty property]; } copy], nil);
	itShouldBehaveLike(RACPropertyMemoryManagementExamples, [^{ return [RACProperty property]; } copy], nil);
});

SpecEnd
