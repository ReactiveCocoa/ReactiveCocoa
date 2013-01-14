//
//  RACPropertySubjectSpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject.h"
#import "RACPropertySubjectExamples.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "NSObject+RACPropertySubscribing.h"

SpecBegin(RACPropertySubject)

describe(@"RACPropertySubject", ^{
	itShouldBehaveLike(RACPropertySubjectExamples, ^{
		return @{
			RACPropertySubjectExampleGetPropertyBlock: [^{ return [RACPropertySubject property]; } copy]
		};
	});
});

SpecEnd
