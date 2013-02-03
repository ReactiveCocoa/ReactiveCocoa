//
//  RACSignalCommandSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-02-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalCommand.h"
#import "RACCommandExamples.h"

SpecBegin(RACSignalCommand)

itShouldBehaveLike(RACCommandExamples, @{ RACCommandExamplesClass: RACSignalCommand.class });

SpecEnd
