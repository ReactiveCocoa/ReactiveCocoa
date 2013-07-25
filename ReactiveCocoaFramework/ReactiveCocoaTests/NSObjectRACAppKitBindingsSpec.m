//
//  NSObjectRACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBindingExamples.h"

#import "EXTKeyPathCoding.h"
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
	
itShouldBehaveLike(RACViewBindingExamples, ^{
	return @{
		RACViewBindingExampleView: textField,
		RACViewBindingExampleKeyPath: @keypath(textField.stringValue),
		RACViewBindingExampleCreateEndpointBlock: ^{
			return [textField rac_bind:NSValueBinding];
		}
	};
});

describe(@"value binding", ^{
	__block RACBindingEndpoint *valueEndpoint;

	beforeEach(^{
		valueEndpoint = [textField rac_bind:NSValueBinding];
		expect(valueEndpoint).notTo.beNil();
	});

	it(@"should not have a starting value", ^{
		__block BOOL receivedNext = NO;
		[valueEndpoint subscribeNext:^(id x) {
			receivedNext = YES;
		}];

		expect(receivedNext).to.beFalsy();
	});

	it(@"should send view changes", ^{
		__block NSString *received;
		[valueEndpoint subscribeNext:^(id x) {
			received = x;
		}];

		setText(@"fuzz");
		expect(received).to.equal(@"fuzz");

		setText(@"buzz");
		expect(received).to.equal(@"buzz");
	});

	it(@"should set values on the view", ^{
		[valueEndpoint sendNext:@"fuzz"];
		expect(textField.stringValue).to.equal(@"fuzz");

		[valueEndpoint sendNext:@"buzz"];
		expect(textField.stringValue).to.equal(@"buzz");
	});

	it(@"should not echo changes back to the binding", ^{
		__block NSUInteger receivedCount = 0;
		[valueEndpoint subscribeNext:^(id _) {
			receivedCount++;
		}];

		expect(receivedCount).to.equal(0);

		[valueEndpoint sendNext:@"fuzz"];
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

			RACBindingEndpoint *endpoint = [view rac_bind:NSValueBinding];
			[endpoint subscribeCompleted:^{
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
		__block BOOL endpointDeallocated = NO;

		@autoreleasepool {
			NSTextField *view __attribute__((objc_precise_lifetime)) = [[NSTextField alloc] initWithFrame:NSZeroRect];
			[view.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				viewDeallocated = YES;
			}]];

			RACBindingEndpoint *endpoint = [view rac_bind:NSValueBinding];
			[endpoint.rac_deallocDisposable addDisposable:[RACDisposable disposableWithBlock:^{
				endpointDeallocated = YES;
			}]];

			expect(viewDeallocated).to.beFalsy();
			expect(endpointDeallocated).to.beFalsy();
		}

		expect(viewDeallocated).to.beTruthy();
		expect(endpointDeallocated).will.beTruthy();
	});
});

SpecEnd
