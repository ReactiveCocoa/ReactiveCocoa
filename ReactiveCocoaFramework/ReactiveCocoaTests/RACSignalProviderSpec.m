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
__block RACSignalProvider *foobarProvider;
__block RACSignalProvider *incrementProvider;

beforeEach(^{
	returnProvider = RACSignalProvider.returnProvider;
	expect(returnProvider).notTo.beNil();

	foobarProvider = [RACSignalProvider providerWithSignal:[RACSignal return:@"foobar"]];
	expect(foobarProvider).notTo.beNil();

	incrementProvider = [RACSignalProvider providerWithBlock:^(NSNumber *num) {
		return [RACSignal return:@(num.integerValue + 1)];
	}];

	expect(incrementProvider).notTo.beNil();
});

it(@"should provide a signal for an input", ^{
	expect([[returnProvider signalWithValue:@"fuzzbuzz"] toArray]).to.equal((@[ @"fuzzbuzz" ]));
	expect([[foobarProvider signalWithValue:@"baz"] toArray]).to.equal((@[ @"foobar" ]));
	expect([[incrementProvider signalWithValue:@10] toArray]).to.equal((@[ @11 ]));
});

it(@"should follow with another provider", ^{
	RACSignalProvider *composed = [returnProvider followedBy:incrementProvider];
	expect(composed).notTo.beNil();

	RACSignal *signal = [composed signalWithValue:@1];
	expect([signal toArray]).to.equal((@[ @2 ]));
});

SpecEnd
