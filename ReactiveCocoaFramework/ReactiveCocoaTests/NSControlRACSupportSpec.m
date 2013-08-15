//
//  NSControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACCommandSupport.h"
#import "NSControl+RACTextSignalSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCommand.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSubject.h"

SpecBegin(NSControlRACSupport)

__block RACSubject *enabledSubject;
__block RACCommand *command;

beforeEach(^{
	enabledSubject = [RACSubject subject];
	command = [[RACCommand alloc] initWithEnabled:enabledSubject signalBlock:^(id sender) {
		return [RACSignal return:sender];
	}];
});

describe(@"NSButton", ^{
	__block NSButton *button;

	beforeEach(^{
		button = [[NSButton alloc] initWithFrame:NSZeroRect];
		expect(button).notTo.beNil();

		button.rac_command = command;
	});

	it(@"should bind the button's enabledness to the command's canExecute", ^{
		expect([button isEnabled]).to.beTruthy();

		[enabledSubject sendNext:@NO];
		expect([button isEnabled]).to.beFalsy();
		
		[enabledSubject sendNext:@YES];
		expect([button isEnabled]).to.beTruthy();
	});

	it(@"should execute the button's command when clicked", ^{
		__block BOOL executed = NO;
		[[command.executionSignals flatten] subscribeNext:^(id sender) {
			expect(sender).to.equal(button);
			executed = YES;
		}];
		
		[button performClick:nil];
		expect(executed).to.beTruthy();
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
		
		field.rac_command = command;
	});

	it(@"should bind the text field's enabledness to the command's canExecute", ^{
		expect([field isEnabled]).to.beTruthy();

		[enabledSubject sendNext:@NO];
		expect([field isEnabled]).to.beFalsy();
		
		[enabledSubject sendNext:@YES];
		expect([field isEnabled]).to.beTruthy();
	});

	it(@"should execute the text field's command when editing ends", ^{
		__block BOOL executed = NO;
		[[command.executionSignals flatten] subscribeNext:^(id sender) {
			expect(sender).to.equal(field);
			executed = YES;
		}];
		
		expect([window makeFirstResponder:nil]).to.beTruthy();
		expect(window.firstResponder).to.equal(window);
		expect(executed).to.beTruthy();
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
