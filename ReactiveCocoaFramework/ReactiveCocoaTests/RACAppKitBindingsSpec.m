//
//  RACAppKitBindingsSpec.m
//  ReactiveCocoa
//
//  Created by Maxwell Swadling on 6/05/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPropertySubject.h"
#import "RACBindingExamples.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "NSObject+RACAppKitBindings.h"


SpecBegin(RACAppKitBindings)

describe(@"RACAppKitBindings", ^{
	__block NSTextField *textField;
	id value1 = @"test value 1";
	
	before(^{
		textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
	});
	
	itShouldBehaveLike(RACBindingExamples, ^{
		return @{
			RACBindingExamplesGetBindingBlock1: [^{ return [textField rac_bind:NSValueBinding]; } copy],
			RACBindingExamplesGetBindingBlock2: [^{ return [textField rac_bind:NSValueBinding]; } copy]
	 };
	});
	
	it(@"should send the current value of a binding", ^{
		__block id receivedValue = nil;
		RACBinding *binding = [textField rac_bind:NSValueBinding nilValue:@""];
		[[binding take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		expect(receivedValue).to.equal(@"");
		
		[textField setStringValue:value1];
		[[binding take:1] subscribeNext:^(id x) {
			receivedValue = x;
		}];
		
		expect(receivedValue).to.equal(value1);
	});
	
	
	
//	it(@"should send the object's new value when it's changed", ^{
//		object.name = value1;
//		NSMutableArray *receivedValues = [NSMutableArray array];
//		[property subscribeNext:^(id x) {
//			[receivedValues addObject:x];
//		}];
//		object.name = value2;
//		object.name = value3;
//		expect(receivedValues).to.equal(values);
//	});
	
	
//	it(@"should be able to subscribe to signals", ^{
//		NSMutableArray *receivedValues = [NSMutableArray array];
//		[object rac_addObserver:self forKeyPath:@keypath(object.name) options:NSKeyValueObservingOptionNew block:^(id target, id observer, NSDictionary *change) {
//			[receivedValues addObject:change[NSKeyValueChangeNewKey]];
//		}];
//		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
//			[subscriber sendNext:value1];
//			[subscriber sendNext:value2];
//			[subscriber sendNext:value3];
//			return nil;
//		}];
//		[signal subscribe:property];
//		expect(receivedValues).to.equal(values);
//	});
	
	it(@"should receive values from a binding", ^{
		RACBinding *binding = [textField rac_bind:NSValueBinding nilValue:@""];
		expect(textField.stringValue).to.equal(@"");
		
		[binding sendNext:value1];
		expect(textField.stringValue).to.equal(value1);
	});
	
});

SpecEnd

