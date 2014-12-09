//
//  RACDelegateProxySpec.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-22.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "NSObject+RACSelectorSignal.h"
#import "RACDelegateProxy.h"
#import "RACSignal.h"
#import "RACTuple.h"
#import "RACCompoundDisposable.h"
#import "NSObject+RACDeallocating.h"

@protocol TestDelegateProtocol
- (NSUInteger)lengthOfString:(NSString *)str;
@end

@interface TestDelegate : NSObject <TestDelegateProtocol>
@property (nonatomic, assign) BOOL lengthOfStringInvoked;
@end

QuickSpecBegin(RACDelegateProxySpec)

__block id proxy;
__block TestDelegate *delegate;
__block Protocol *protocol;

qck_beforeEach(^{
	protocol = @protocol(TestDelegateProtocol);
	expect(protocol).notTo(beNil());

	proxy = [[RACDelegateProxy alloc] initWithProtocol:protocol];
	expect(proxy).notTo(beNil());
	expect([proxy rac_proxiedDelegate]).to(beNil());

	delegate = [[TestDelegate alloc] init];
	expect(delegate).notTo(beNil());
});

qck_it(@"should not respond to selectors at first", ^{
	expect(@([proxy respondsToSelector:@selector(lengthOfString:)])).to(beFalsy());
});

qck_it(@"should send on a signal for a protocol method", ^{
	__block RACTuple *tuple;
	[[proxy signalForSelector:@selector(lengthOfString:)] subscribeNext:^(RACTuple *t) {
		tuple = t;
	}];

	expect(@([proxy respondsToSelector:@selector(lengthOfString:)])).to(beTruthy());
	expect(@([proxy lengthOfString:@"foo"])).to(equal(@0));
	expect(tuple).to(equal(RACTuplePack(@"foo")));
});

qck_it(@"should forward to the proxied delegate", ^{
	[proxy setRac_proxiedDelegate:delegate];

	expect(@([proxy respondsToSelector:@selector(lengthOfString:)])).to(beTruthy());
	expect(@([proxy lengthOfString:@"foo"])).to(equal(@3));
	expect(@(delegate.lengthOfStringInvoked)).to(beTruthy());
});

qck_it(@"should not send to the delegate when signals are applied", ^{
	[proxy setRac_proxiedDelegate:delegate];

	__block RACTuple *tuple;
	[[proxy signalForSelector:@selector(lengthOfString:)] subscribeNext:^(RACTuple *t) {
		tuple = t;
	}];

	expect(@([proxy respondsToSelector:@selector(lengthOfString:)])).to(beTruthy());
	expect(@([proxy lengthOfString:@"foo"])).to(equal(@0));

	expect(tuple).to(equal(RACTuplePack(@"foo")));
	expect(@(delegate.lengthOfStringInvoked)).to(beFalsy());
});

QuickSpecEnd

@implementation TestDelegate

- (NSUInteger)lengthOfString:(NSString *)str {
	self.lengthOfStringInvoked = YES;
	return str.length;
}

@end
