//
//  NSObjectRACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBindingExamples.h"

#import "NSObject+RACAppKitBindings.h"
#import "NSObject+RACDeallocating.h"
#import "RACBinding.h"
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

itShouldBehaveLike(RACBindingExamples, @{
	RACBindingExampleCreateBlock: [^{
		return [textField rac_bind:NSValueBinding];
	} copy]
});

describe(@"value binding", ^{
	__block RACBinding *valueBinding;

	beforeEach(^{
		valueBinding = [textField rac_bind:NSValueBinding];
		expect(valueBinding).notTo.beNil();
	});

	it(@"should start with nil", ^{
		expect([valueBinding.rumorsSignal first]).to.beNil();
	});

	it(@"should send view changes as rumors", ^{
		__block NSString *received;
		[valueBinding.rumorsSignal subscribeNext:^(id x) {
			received = x;
		}];

		setText(@"fuzz");
		expect(received).to.equal(@"fuzz");

		setText(@"buzz");
		expect(received).to.equal(@"buzz");
	});

	it(@"should set facts on the view", ^{
		[valueBinding.factsSubscriber sendNext:@"fuzz"];
		expect(textField.stringValue).to.equal(@"fuzz");

		[valueBinding.factsSubscriber sendNext:@"buzz"];
		expect(textField.stringValue).to.equal(@"buzz");
	});

	it(@"should not echo changes back to the binding", ^{
		__block NSUInteger receivedCount = 0;
		[valueBinding.rumorsSignal subscribeNext:^(id _) {
			receivedCount++;
		}];

		expect(receivedCount).to.equal(1);

		[valueBinding.factsSubscriber sendNext:@"fuzz"];
		expect(receivedCount).to.equal(1);

		setText(@"buzz");
		expect(receivedCount).to.equal(2);
	});

	it(@"should complete when the view deallocates", ^{
		__block BOOL deallocated = NO;
		__block BOOL factsCompleted = NO;
		__block BOOL rumorsCompleted = NO;

		@autoreleasepool {
			NSTextField *view __attribute__((objc_precise_lifetime)) = [[NSTextField alloc] initWithFrame:NSZeroRect];
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				deallocated = YES;
			}]];

			RACBinding *binding = [view rac_bind:NSValueBinding];
			[binding.factsSignal subscribeCompleted:^{
				factsCompleted = YES;
			}];

			[binding.rumorsSignal subscribeCompleted:^{
				rumorsCompleted = YES;
			}];

			expect(deallocated).to.beFalsy();
			expect(factsCompleted).to.beFalsy();
			expect(rumorsCompleted).to.beFalsy();
		}

		expect(deallocated).to.beTruthy();
		expect(factsCompleted).to.beTruthy();
		expect(rumorsCompleted).to.beTruthy();
	});

	it(@"should deallocate after the view deallocates", ^{
		__block BOOL viewDeallocated = NO;
		__block BOOL bindingDeallocated = NO;

		@autoreleasepool {
			NSTextField *view __attribute__((objc_precise_lifetime)) = [[NSTextField alloc] initWithFrame:NSZeroRect];
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				viewDeallocated = YES;
			}]];

			RACBinding *binding = [view rac_bind:NSValueBinding];
			[binding.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				bindingDeallocated = YES;
			}]];

			expect(viewDeallocated).to.beFalsy();
			expect(bindingDeallocated).to.beFalsy();
		}

		expect(viewDeallocated).to.beTruthy();
		expect(bindingDeallocated).will.beTruthy();
	});
});

SpecEnd
