//
//  UITextViewRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "UITextView+RACSignalSupport.h"

SpecBegin(UITextViewRACSupport)

describe(@"-rac_textSignal", ^{
	__block UITextView *textView;

	beforeEach(^{
		textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 100, 20)];
		expect(textView).notTo.beNil();
	});

	it(@"should start with the initial text", ^{
		textView.text = @"foo";

		RACSignal *textSignal = textView.rac_textSignal;
		expect([textSignal first]).to.equal(@"foo");

		textView.text = @"bar";
		expect([textSignal first]).to.equal(@"bar");
	});
});

SpecEnd
