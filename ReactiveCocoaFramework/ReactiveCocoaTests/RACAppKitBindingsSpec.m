//
//  RACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Maxwell Swadling on 6/05/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject.h"
#import "RACBindingExamples.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "NSObject+RACAppKitBindings.h"

SpecBegin(RACAppKitBindings)

describe(@"RACAppKitBindings", ^{
	__block NSTextField *textField;
	
	before(^{
		textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
	});
	
	itShouldBehaveLike(RACBindingExamples, ^{
		return @{
			RACBindingExamplesGetBindingBlock1: [^{ return [textField rac_bind:NSValueBinding]; } copy],
			RACBindingExamplesGetBindingBlock2: [^{ return [textField rac_bind:NSValueBinding]; } copy],
			RACBindingExamplesGetProperty: [^{ return [textField rac_bind:NSValueBinding]; } copy]
	 };
	});
});

SpecEnd

