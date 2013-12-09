//
//  NSControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"

SpecBegin(NSControlRACSupport)

describe(@"NSButton", ^{
	__block NSButton *button;

	beforeEach(^{
		button = [[NSButton alloc] initWithFrame:NSZeroRect];
		expect(button).notTo.beNil();
	});

	it(@"should send on rac_actionSignal", ^{
		RACSignal *actionSignal = button.rac_actionSignal;
		expect(button.target).to.beNil();
		expect(button.action).to.beNil();

		__block id sender = nil;
		[actionSignal subscribeNext:^(id x) {
			sender = x;
		}];

		expect(button.target).notTo.beNil();
		expect(button.action).notTo.beNil();
		expect(sender).to.beNil();

		[button performClick:self];
		expect(sender).notTo.beNil();
	});
});

describe(@"NSTextField", ^{
	__block NSTextField *field;
	__block NSWindow *window;
	
	beforeEach(^{
		field = [[NSTextField alloc] initWithFrame:NSZeroRect];
		expect(field).notTo.beNil();

		[field.cell setSendsActionOnEndEditing:YES];

		window = [[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO];
		expect(window).notTo.beNil();

		[window.contentView addSubview:field];

		expect([window makeFirstResponder:field]).to.beTruthy();
		expect(window.firstResponder).notTo.equal(window);
	});

	it(@"should send on rac_actionSignal", ^{
		RACSignal *actionSignal = field.rac_actionSignal;
		expect(field.target).to.beNil();
		expect(field.action).to.beNil();

		__block id sender = nil;
		[actionSignal subscribeNext:^(id x) {
			sender = x;
		}];

		expect(field.target).notTo.beNil();
		expect(field.action).notTo.beNil();
		expect(sender).to.beNil();

		expect([window makeFirstResponder:nil]).to.beTruthy();
		expect(window.firstResponder).to.equal(window);
		expect(sender).notTo.beNil();
	});

	describe(@"-rac_textSignal", ^{
		it(@"should send changes", ^{
			NSMutableArray *strings = [NSMutableArray array];
			[field.rac_textSignal subscribeNext:^(NSString *str) {
				[strings addObject:str];
			}];

			expect(strings).to.equal(@[ @"" ]);

			NSText *fieldEditor = (id)window.firstResponder;
			expect(fieldEditor).to.beKindOf(NSText.class);

			[fieldEditor insertText:@"f"];
			[fieldEditor insertText:@"o"];
			[fieldEditor insertText:@"b"];

			NSArray *expected = @[ @"", @"f", @"fo", @"fob" ];
			expect(strings).to.equal(expected);
		});

		it(@"shouldn't give the text field eternal life", ^{
			__block BOOL dealloced = NO;
			@autoreleasepool {
				NSTextField *field __attribute__((objc_precise_lifetime)) = [[NSTextField alloc] initWithFrame:CGRectZero];
				[field.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
					dealloced = YES;
				}]];
				[field.rac_textSignal subscribeNext:^(id x) {

				}];
			}

			expect(dealloced).will.beTruthy();
		});
	});
});

SpecEnd
