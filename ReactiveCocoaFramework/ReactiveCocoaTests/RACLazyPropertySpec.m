//
//  RACLazyPropertySpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACLazyProperty.h"
#import "RACPropertyExamples.h"

SpecBegin(RACLazyProperty)

describe(@"RACProperty", ^{
	itShouldBehaveLike(RACPropertyExamples, [^{ return [RACLazyProperty lazyPropertyWithStart:[RACSignal return:nil]]; } copy], nil);
});

SpecEnd
