//
//  RACPropertySpec.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 30/12/2012.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACProperty.h"
#import "RACPropertyExamples.h"
#import "RACBinding.h"
#import "RACDisposable.h"
#import "NSObject+RACPropertySubscribing.h"

SpecBegin(RACProperty)

describe(@"RACProperty", ^{
	itShouldBehaveLike(RACPropertyExamples, [^{ return [RACProperty property]; } copy], nil);
	
	it(@"should dealloc when it's subscribers are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = [RACProperty property];
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [property subscribeNext:^(id x) {}];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc when it's subscriptions are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = [RACProperty property];
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [RACSignal.never subscribe:property];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc when it's binding's subscribers are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = [RACProperty property];
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [[property binding] subscribeNext:^(id x) {}];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc when it's binding's subscriptions are disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd = NO;
		@autoreleasepool {
			RACProperty *property __attribute__((objc_precise_lifetime)) = [RACProperty property];
			[property rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd = YES;
			}]];
			disposable = [RACSignal.never subscribe:[property binding]];
		}
		[disposable dispose];
		expect(deallocd).will.beTruthy();
	});
	
	it(@"should dealloc if it's binding with other properties is disposed", ^{
		RACDisposable *disposable = nil;
		__block BOOL deallocd1 = NO;
		__block BOOL deallocd2 = NO;
		@autoreleasepool {
			RACProperty *property1 __attribute__((objc_precise_lifetime)) = [RACProperty property];
			RACProperty *property2 __attribute__((objc_precise_lifetime)) = [RACProperty property];
			[property1 rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd1 = YES;
			}]];
			[property2 rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				deallocd2 = YES;
			}]];
			disposable = [[property1 binding] bindTo:[property2 binding]];
		}
		[disposable dispose];
		expect(deallocd1).will.beTruthy();
		expect(deallocd2).will.beTruthy();
	});
});

SpecEnd
