//
//  UIButtonRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Ash Furrow on 2013-06-06.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"
#import "RACTestUIButton.h"

#import "UIButton+RACSupport.h"
#import "RACDisposable.h"

SpecBegin(UIButtonRACSupport)

describe(@"UIButton", ^{
	__block UIButton *button;
	
	beforeEach(^{
		button = [RACTestUIButton button];
		expect(button).notTo.beNil();
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: button,
			RACControlActionExampleActivateBlock: ^(UIButton *button) {
				[button sendActionsForControlEvents:UIControlEventTouchUpInside];
			}
		};
	});
});

SpecEnd
