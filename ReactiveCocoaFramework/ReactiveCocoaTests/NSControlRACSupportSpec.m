//
//  NSControlRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/4/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACControlCommandExamples.h"

#import "NSControl+RACCommandSupport.h"
#import "NSControl+RACTextSignalSupport.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACPropertySubscribing.h"
#import "RACCommand.h"
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

	itShouldBehaveLike(RACControlCommandExamples, ^{
		return @{
			RACControlCommandExampleControl: button,
			RACControlCommandExampleActivateBlock: ^(NSButton *button) {
				[button performClick:nil];
			}
		};
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

	itShouldBehaveLike(RACControlCommandExamples, ^{
		return @{
			RACControlCommandExampleControl: field,
			RACControlCommandExampleActivateBlock: ^(NSTextField *field) {
				expect([window makeFirstResponder:nil]).to.beTruthy();
				expect(window.firstResponder).to.equal(window);
			}
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
