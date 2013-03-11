//
//  NSControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSControl+RACCommandSupport.h"
#import "NSControl+RACTextSignalSupport.h"
#import "RACCommand.h"

SpecBegin(NSControlRACSupport)

describe(@"NSButton", ^{
	__block NSButton *button;

	beforeEach(^{
		button = [[NSButton alloc] initWithFrame:NSZeroRect];
		expect(button).notTo.beNil();
	});

	it(@"should bind the button's enabledness to the command's canExecute", ^{
		button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
		expect([button isEnabled]).to.beFalsy();
		
		button.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
		expect([button isEnabled]).to.beTruthy();
	});

	it(@"should execute the button's command when clicked", ^{
		RACCommand *command = [RACCommand command];

		__block BOOL executed = NO;
		[command subscribeNext:^(id sender) {
			expect(sender).to.equal(button);
			executed = YES;
		}];
		
		button.rac_command = command;
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
	});

	it(@"should bind the text field's enabledness to the command's canExecute", ^{
		field.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@NO]];
		expect([field isEnabled]).to.beFalsy();
		
		field.rac_command = [RACCommand commandWithCanExecuteSignal:[RACSignal return:@YES]];
		expect([field isEnabled]).to.beTruthy();
	});

	it(@"should execute the text field's command when editing ends", ^{
		RACCommand *command = [RACCommand command];

		__block BOOL executed = NO;
		[command subscribeNext:^(id sender) {
			expect(sender).to.equal(field);
			executed = YES;
		}];
		
		field.rac_command = command;
		expect([window makeFirstResponder:nil]).to.beTruthy();
		expect(window.firstResponder).to.equal(window);
		
		expect(executed).to.beTruthy();
	});

	it(@"should send changes on rac_textSignal", ^{
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
});

SpecEnd
