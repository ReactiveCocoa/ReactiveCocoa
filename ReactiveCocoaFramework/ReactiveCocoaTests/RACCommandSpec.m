//
//  RACCommandSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 8/31/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACCommand.h"
#import "RACCommandExamples.h"

SpecBegin(RACCommand)

itShouldBehaveLike(RACCommandExamples, @{ RACCommandExamplesClass: RACCommand.class });

SpecEnd
