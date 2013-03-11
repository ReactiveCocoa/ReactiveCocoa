//
//  NSTextRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-03-08.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSText+RACSignalSupport.h"
#import "RACSignal.h"

SpecBegin(NSTextRACSupport)

it(@"NSTextView should send changes on rac_textSignal", ^{
	NSTextView *textView = [[NSTextView alloc] initWithFrame:NSZeroRect];
	expect(textView).notTo.beNil();

	NSMutableArray *strings = [NSMutableArray array];
	[textView.rac_textSignal subscribeNext:^(NSString *str) {
		[strings addObject:str];
	}];

	expect(strings).to.equal(@[ @"" ]);

	[textView insertText:@"f"];
	[textView insertText:@"o"];
	[textView insertText:@"b"];

	NSArray *expected = @[ @"", @"f", @"fo", @"fob" ];
	expect(strings).to.equal(expected);
});

SpecEnd
