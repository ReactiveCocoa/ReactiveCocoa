//
//  RACKVOWrapperSpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2012-08-07.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACSpecs.h"
#import "NSObject+RACKVOWrapper.h"

SpecBegin(RACKVOWrapper)

it(@"should add and remove an observer", ^{
	NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{}];
	expect(operation).notTo.beNil();

	__block BOOL notified = NO;
	id identifier = [operation rac_addObserver:self forKeyPath:@"isFinished" options:NSKeyValueObservingOptionNew queue:nil block:^(id target, NSDictionary *change){
		expect(target).to.equal(self);
		expect([change objectForKey:NSKeyValueChangeNewKey]).to.equal(@YES);

		expect(notified).to.beFalsy();
		notified = YES;
	}];

	expect(identifier).notTo.beNil();

	[operation start];
	[operation waitUntilFinished];

	expect(notified).will.beTruthy();
	expect([operation rac_removeObserverWithIdentifier:identifier]).to.beTruthy();
});

SpecEnd
