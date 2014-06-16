//
//  NSControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACControlActionExamples.h"

#import "NSControl+RACSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACAction.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"

SpecBegin(NSControlRACSupport)

describe(@"NSButton", ^{
	__block NSButton *button;

	void (^activate)(NSControl *) = ^(id _) {
		[button performClick:self];
	};

	beforeEach(^{
		button = [[NSButton alloc] initWithFrame:NSZeroRect];
		expect(button).notTo.beNil();
	});

	it(@"should send on rac_actionSignal", ^{
		RACSignal *actionSignal = button.rac_actionSignal;
		expect(button.target).to.beNil();
		expect(button.action).to.beNil();

		__block id value = nil;
		[actionSignal subscribeNext:^(id x) {
			value = x;
		}];

		expect(button.target).notTo.beNil();
		expect(button.action).notTo.beNil();
		expect(value).to.beNil();

		activate(button);
		expect(value).to.beIdenticalTo(button);
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: button,
			RACControlActionExampleActivateBlock: activate
		};
	});
});

describe(@"NSTextField", ^{
	__block NSTextField *field;
	__block NSWindow *window;

	void (^activate)(NSControl *) = ^(id _) {
		expect([window makeFirstResponder:nil]).to.beTruthy();
		expect(window.firstResponder).to.equal(window);
	};
	
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

		__block id value = nil;
		[actionSignal subscribeNext:^(id x) {
			value = x;
		}];

		expect(field.target).notTo.beNil();
		expect(field.action).notTo.beNil();
		expect(value).to.beNil();

		activate(field);
		expect(value).to.beIdenticalTo(field);
	});

	itShouldBehaveLike(RACControlActionExamples, ^{
		return @{
			RACControlActionExampleControl: field,
			RACControlActionExampleActivateBlock: activate
		};
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
