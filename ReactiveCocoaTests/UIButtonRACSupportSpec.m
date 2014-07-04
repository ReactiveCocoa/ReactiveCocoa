//
//  UIButtonRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlCommandExamples.h"
#import "RACTestUIButton.h"

#import "UIButton+RACCommandSupport.h"
#import "RACCommand.h"
#import "RACDisposable.h"

SpecBegin(UIButtonRACSupport)

describe(@"UIButton", ^{
	__block UIButton *button;
	
	beforeEach(^{
		button = [RACTestUIButton button];
		expect(button).notTo.beNil();
	});

	itShouldBehaveLike(RACControlCommandExamples, ^{
		return @{
			RACControlCommandExampleControl: button,
			RACControlCommandExampleActivateBlock: ^(UIButton *button) {
				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
				[button sendActionsForControlEvents:UIControlEventTouchUpInside];
				#pragma clang diagnostic pop
			}
		};
	});
});

SpecEnd
