#import "RACSlimSignal.h"
#import "RACDisposable.h"
#import "RACSubscriber.h"

SpecBegin(RACSlimSignal)

it(@"should act like RACSignal.never when initialized with no arguments", ^{
	RACSlimSignal* r = [RACSlimSignal new];
	
	__block bool didAnything = false;
	[[r subscribeNext:^(id x) {
		didAnything = true;
	} error:^(NSError *error) {
		didAnything = true;
	} completed:^{
		didAnything = true;
	}] dispose];
	expect(didAnything).to.beFalsy;
	
});

it(@"should call the block it is initialized with", ^{
	__block int callsToBlock = 0;
	RACSlimSignal* r = [RACSlimSignal slimSignalWithSubscribe:^RACDisposable *(id<RACSubscriber> subscriber) {
		callsToBlock++;
		return nil;
	}];
	
	expect(callsToBlock).to.equal(0);
	[r subscribeNext:^(id x) {}];
	expect(callsToBlock).to.equal(1);
});

it(@"should dispose with the block's result", ^{
	__block int callsToDispose = 0;
	RACSlimSignal* r = [RACSlimSignal slimSignalWithSubscribe:^RACDisposable *(id<RACSubscriber> subscriber) {
		return [RACDisposable disposableWithBlock:^{
			callsToDispose++;
		}];
	}];
	RACDisposable* d = [r subscribeNext:^(id x){}];
	
	expect(callsToDispose).to.equal(0);
	[d dispose];
	expect(callsToDispose).to.equal(1);
});

it(@"should forward to the given subscriber", ^{
	__block int callsToNext = 0;
	RACSlimSignal* r = [RACSlimSignal slimSignalWithSubscribe:^RACDisposable *(id<RACSubscriber> subscriber) {
		[subscriber sendNext:@1];
		return nil;
	}];
	
	expect(callsToNext).to.equal(0);
	[r subscribeNext:^(id x) {
		callsToNext++;
	}];
	expect(callsToNext).to.equal(1);
});

SpecEnd
