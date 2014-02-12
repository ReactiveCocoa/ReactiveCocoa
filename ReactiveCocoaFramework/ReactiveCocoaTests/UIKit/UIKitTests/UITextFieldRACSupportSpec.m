//
//  UITextFieldRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "UITextField+RACSignalSupport.h"

SpecBegin(UITextFieldRACSupport)

describe(@"-rac_textSignal", ^{
	__block UITextField *textField;

	beforeEach(^{
		textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 20)];
		expect(textField).notTo.beNil();
	});

	it(@"should start with the initial text", ^{
		textField.text = @"foo";

		RACSignal *textSignal = textField.rac_textSignal;
		expect([textSignal first]).to.equal(@"foo");

		textField.text = @"bar";
		expect([textSignal first]).to.equal(@"bar");
	});

	it(@"should clear text upon editing", ^{
		textField.text = @"foo";
		textField.clearsOnBeginEditing = YES;

		UIWindow *win = [UIWindow new];
		[win addSubview:textField];

		__block NSString *str = @"bar";

		RACSignal *textSignal = textField.rac_textSignal;
		[textSignal subscribeNext:^(id x) {
			str = x;
		}];
		expect(str).to.equal(@"foo");

		[textField becomeFirstResponder];
		expect(str).to.equal(@"");
	});
});

SpecEnd
