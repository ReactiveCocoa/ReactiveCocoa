//
//  RACSignalProviderSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-10-18.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignalProvider.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"

SpecBegin(RACSignalProvider)

__block RACSignalProvider *returnProvider;
__block RACSignalProvider *incrementProvider;

beforeEach(^{
	returnProvider = [RACSignalProvider providerWithBlock:^(id x) {
		return [RACSignal return:x];
	}];

	incrementProvider = [RACSignalProvider providerWithBlock:^(NSNumber *num) {
		return [RACSignal return:@(num.integerValue + 1)];
	}];

	expect(returnProvider).notTo.beNil();
	expect(returnProvider).notTo.beNil();
});

it(@"should provide a signal for an input", ^{
	RACSignal *signal = [returnProvider provide:@"foobar"];
	expect([signal toArray]).to.equal((@[ @"foobar" ]));
});

it(@"should follow with another provider", ^{
	RACSignalProvider *composed = [returnProvider followedBy:incrementProvider];
	expect(composed).notTo.beNil();

	RACSignal *signal = [composed provide:@1];
	expect([signal toArray]).to.equal((@[ @2 ]));
});

describe(@"-flattenProvide:", ^{
	it(@"should provide signals for each value", ^{
		RACSignal *signal = [RACSignal createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
			[subscriber sendNext:@1];
			[subscriber sendNext:@2];
			[subscriber sendNext:@5];
			[subscriber sendCompleted];
			return nil;
		}];
		
		RACSignal *flattened = [signal flattenProvide:incrementProvider];
		expect([flattened toArray]).to.equal((@[ @2, @3, @6 ]));
	});
});

SpecEnd
