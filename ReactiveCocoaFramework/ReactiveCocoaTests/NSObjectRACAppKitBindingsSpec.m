//
//  NSObjectRACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACChannelExamples.h"

#import "EXTKeyPathCoding.h"
#import "NSObject+RACAppKitBindings.h"
#import "NSObject+RACDeallocating.h"
#import "RACChannel.h"
#import "RACCompoundDisposable.h"
#import "RACDisposable.h"
#import "RACSignal+Operations.h"

SpecBegin(NSObjectRACAppKitBindings)

__block NSTextField *textField;
__block void (^setText)(NSString *);

beforeEach(^{
	textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
	expect(textField).notTo.beNil();

	setText = [^(NSString *text) {
		textField.stringValue = text;

		// Bindings don't actually trigger from programmatic modification. Do it
		// manually.
		NSDictionary *bindingInfo = [textField infoForBinding:NSValueBinding];
		[bindingInfo[NSObservedObjectKey] setValue:text forKeyPath:bindingInfo[NSObservedKeyPathKey]];
	} copy];
});
	
itShouldBehaveLike(RACViewChannelExamples, ^{
	return @{
		RACViewChannelExampleView: textField,
		RACViewChannelExampleKeyPath: @keypath(textField.stringValue),
		RACViewChannelExampleCreateTerminalBlock: ^{
			return [textField rac_bind:NSValueBinding];
		}
	};
});

describe(@"value binding", ^{
	__block RACChannelTerminal *valueTerminal;

	beforeEach(^{
		valueTerminal = [textField rac_bind:NSValueBinding];
		expect(valueTerminal).notTo.beNil();
	});

	it(@"should not have a starting value", ^{
		__block BOOL receivedNext = NO;
		[valueTerminal subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();
	});

	it(@"should send view changes", ^{
		__block NSString *received;
		[valueTerminal subscribeNext:^(id x) {
			received = x;
		}];

		setText(@"fuzz");
		expect(received).to.equal(@"fuzz");

		setText(@"buzz");
		expect(received).to.equal(@"buzz");
	});

	it(@"should set values on the view", ^{
		[valueTerminal sendNext:@"fuzz"];
		expect(textField.stringValue).to.equal(@"fuzz");

		[valueTerminal sendNext:@"buzz"];
		expect(textField.stringValue).to.equal(@"buzz");
	});

	it(@"should not echo changes back to the channel", ^{
		__block NSUInteger receivedCount = 0;
		[valueTerminal subscribeNext:^(id _) {
			receivedCount++;
		}];

		expect(receivedCount).to.equal(0);

		[valueTerminal sendNext:@"fuzz"];
		expect(receivedCount).to.equal(0);

		setText(@"buzz");
		expect(receivedCount).to.equal(1);
	});

	it(@"should complete when the view deallocates", ^{
		__block BOOL deallocated = NO;
		__block BOOL completed = NO;

		@autoreleasepool {
			NSTextField *view __attribute__((objc_precise_lifetime)) = [[NSTextField alloc] initWithFrame:NSZeroRect];
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			RACChannelTerminal *terminal = [view rac_bind:NSValueBinding];
			[terminal subscribeCompleted:^{
				completed = YES;
			}];

			expect(deallocated).to.beFalsy();
			expect(completed).to.beFalsy();
		}

		expect(deallocated).to.beTruthy();
		expect(completed).to.beTruthy();
	});

	it(@"should deallocate after the view deallocates", ^{
		__block BOOL viewDeallocated = NO;
		__block BOOL terminalDeallocated = NO;

		@autoreleasepool {
			NSTextField *view __attribute__((objc_precise_lifetime)) = [[NSTextField alloc] initWithFrame:NSZeroRect];
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				viewDeallocated = YES;
			}]];

			RACChannelTerminal *terminal = [view rac_bind:NSValueBinding];
			[terminal.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				terminalDeallocated = YES;
			}]];

			expect(viewDeallocated).to.beFalsy();
			expect(terminalDeallocated).to.beFalsy();
		}

		expect(viewDeallocated).to.beTruthy();
		expect(terminalDeallocated).will.beTruthy();
	});
});

SpecEnd
