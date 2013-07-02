//
//  NSObjectRACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-07-01.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "NSObject+RACAppKitBindings.h"
#import "RACBinding.h"
#import "RACSignal+Operations.h"

SpecBegin(NSObjectRACAppKitBindings)

__block NSTextField *textField;
__block RACBinding *valueBinding;

beforeEach(^{
	textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
	expect(textField).notTo.beNil();

	textField.stringValue = @"foobar";

	valueBinding = [textField rac_bind:NSValueBinding];
	expect(valueBinding).notTo.beNil();
});

it(@"should start with the value of the text view", ^{
	expect([valueBinding first]).to.equal(@"foobar");
});

it(@"should send text view changes", ^{
	__block NSString *received;
	[valueBinding subscribeNext:^(id x) {
		received = x;
	}];

	textField.stringValue = @"fuzz";
	expect(received).to.equal(@"fuzz");

	textField.stringValue = @"buzz";
	expect(received).to.equal(@"buzz");
});

it(@"should send binding changes", ^{
	[valueBinding sendNext:@"fuzz"];
	expect(textField.stringValue).to.equal(@"fuzz");

	[valueBinding sendNext:@"buzz"];
	expect(textField.stringValue).to.equal(@"buzz");
});

it(@"should not echo changes back to the binding", ^{
	__block NSUInteger receivedCount = 0;
	[valueBinding subscribeNext:^(id _) {
		receivedCount++;
	}];

	expect(receivedCount).to.equal(1);

	[valueBinding sendNext:@"fuzz"];
	expect(receivedCount).to.equal(1);

	textField.stringValue = @"buzz";
	expect(receivedCount).to.equal(2);
});

SpecEnd
