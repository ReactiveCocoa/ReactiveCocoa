#import "RACSlimSignal.h"
#import "RACDisposable.h"
#import "RACSubscriber.h"

SpecBegin(RACSlimSignal)

it(@"should act like RACSignal.never when initialized with no arguments", ^{
	RACSlimSignal *r = [RACSlimSignal new];
	
	__block BOOL didAnything = NO;
	[[r subscribeNext:^(id x) {
		didAnything = YES;
	} error:^(NSError *error) {
		didAnything = YES;
	} completed:^{
		didAnything = YES;
	}] dispose];
	expect(didAnything).to.beFalsy;
	
});

it(@"should call the block it is initialized with", ^{
	__block NSUInteger callsToBlock = 0;
	RACSlimSignal *r = [RACSlimSignal slimSignalWithSubscribe:^(id<RACSubscriber> subscriber) {
		callsToBlock++;
		return (RACDisposable *)nil;
	}];
	
	expect(callsToBlock).to.equal(0);
	[r subscribeNext:^(id x) {}];
	expect(callsToBlock).to.equal(1);
});

it(@"should dispose with the block's result", ^{
	__block NSUInteger callsToDispose = 0;
	RACSlimSignal *r = [RACSlimSignal slimSignalWithSubscribe:^(id<RACSubscriber> subscriber) {
		return [RACDisposable disposableWithBlock:^{
			callsToDispose++;
		}];
	}];
	RACDisposable *d = [r subscribeNext:^(id x){}];
	
	expect(callsToDispose).to.equal(0);
	[d dispose];
	expect(callsToDispose).to.equal(1);
});

it(@"should forward to the given subscriber", ^{
	__block NSUInteger callsToNext = 0;
	RACSlimSignal *r = [RACSlimSignal slimSignalWithSubscribe:^(id<RACSubscriber> subscriber) {
		[subscriber sendNext:@1];
		return (RACDisposable *)nil;
	}];
	
	expect(callsToNext).to.equal(0);
	[r subscribeNext:^(id x) {
		callsToNext++;
	}];
	expect(callsToNext).to.equal(1);
});

SpecEnd
