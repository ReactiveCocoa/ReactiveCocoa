//
//  RACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Maxwell Swadling on 6/05/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACAppKitBindings.h"
#import "RACBinding.h"
#import "RACTestObject.h"

SpecBegin(RACAppKitBindings)

describe(@"RACAppKitBindings", ^{
	
	id value1 = @"test value 1";
	
	it(@"should send binding values", ^{
		__block id receivedValue = nil;
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
		RACBinding *binding = [textField rac_bind:NSValueBinding nilValue:@""];
		
		[textField setStringValue:value1];
		[[binding take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(value1);
		
	});
	
	it(@"should receive values and bind them", ^{
		__block id receivedValue = nil;
		NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
		RACBinding *binding = [textField rac_bind:NSValueBinding];
		
		[binding sendNext:value1];
		
		expect(textField.stringValue).to.equal(value1);

	});
	
	it(@"should bind RACBindings together", ^{
		expect(@"Alas, it does not").to.equal(YES);
	});
});

SpecEnd
