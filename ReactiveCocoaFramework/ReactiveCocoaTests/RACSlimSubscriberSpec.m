#import "RACSlimSubscriber.h"
#import "RACDisposable.h"
#import "RACSignal.h"

SpecBegin(RACSlimSubscriber)

it(@"should forward to the given next block", ^{
	__block int callsToNext = 0;
	__block id lastNext = nil;
	RACSlimSubscriber* r = [RACSlimSubscriber
							slimSubscriberWithNext:^(id x) {
								callsToNext++;
								lastNext = x;
							}
							andError:nil
							andCompleted:nil
							andDidSubscribeWith:nil];
	
	expect(callsToNext).to.equal(0);
	[r sendNext:@""];
	expect(callsToNext).to.equal(1);
	expect(lastNext).to.equal(@"");
});

it(@"should forward to the given blocks", ^{
	__block int callsToError = 0;
	__block id lastError = nil;
	RACSlimSubscriber* r = [RACSlimSubscriber
							slimSubscriberWithNext:nil
							andError:^(NSError *error) {
								callsToError++;
								lastError = error;
							}
							andCompleted:nil
							andDidSubscribeWith:nil];
	
	expect(callsToError).to.equal(0);
	NSError* e = [NSError errorWithDomain:@"" code:0 userInfo:@{}];
	[r sendError:e];
	expect(callsToError).to.equal(1);
	expect(lastError).to.equal(e);
});

it(@"should forward to the given blocks", ^{
	__block int callsToCompleted = 0;
	RACSlimSubscriber* r = [RACSlimSubscriber
							slimSubscriberWithNext:nil
							andError:nil
							andCompleted:^{
								callsToCompleted++;
							}
							andDidSubscribeWith:nil];
	
	expect(callsToCompleted).to.equal(0);
	[r sendCompleted];
	expect(callsToCompleted).to.equal(1);
});







it(@"should override next", ^{
	__block int callsToNext = 0;
	__block id lastNext = nil;
	RACSlimSubscriber* r = [[RACSlimSubscriber
							 slimSubscriberWithNext:nil
							 andError:nil
							 andCompleted:nil
							 andDidSubscribeWith:nil]
							withSendNext:^(id x) {
								callsToNext++;
								lastNext = x;
							}];
	
	expect(callsToNext).to.equal(0);
	[r sendNext:@""];
	expect(callsToNext).to.equal(1);
	expect(lastNext).to.equal(@"");
});

it(@"should override error", ^{
	__block int callsToError = 0;
	__block id lastError = nil;
	RACSlimSubscriber* r = [[RACSlimSubscriber
							 slimSubscriberWithNext:nil
							 andError:nil
							 andCompleted:nil
							 andDidSubscribeWith:nil]
							withSendError:^(NSError* error) {
								callsToError++;
								lastError = error;
							}];
	
	expect(callsToError).to.equal(0);
	NSError* e = [NSError errorWithDomain:@"" code:0 userInfo:@{}];
	[r sendError:e];
	expect(callsToError).to.equal(1);
	expect(lastError).to.equal(e);
});

it(@"should override complete", ^{
	__block int callsToCompleted = 0;
	RACSlimSubscriber* r = [[RACSlimSubscriber
							 slimSubscriberWithNext:nil
							 andError:nil
							 andCompleted:nil
							 andDidSubscribeWith:nil]
							withSendCompleted:^{
								callsToCompleted++;
							}];
	
	expect(callsToCompleted).to.equal(0);
	[r sendCompleted];
	expect(callsToCompleted).to.equal(1);
});

it(@"should return self when wrapped", ^{
	RACSlimSubscriber* r = [RACSlimSubscriber new];
	RACSlimSubscriber* w = [RACSlimSubscriber slimSubscriberWrapping:r];
	expect(r).to.equal(w);
});

it(@"should wrap arbitrary subjects", ^{
	RACSignal* t = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
		RACSlimSubscriber* s = [RACSlimSubscriber slimSubscriberWrapping:subscriber];
		[s sendNext:@1];
		[s sendCompleted];
		return nil;
	}];
	
	__block bool didComplete = false;
	__block bool didError = false;
	__block bool didGetNext = false;
	RACDisposable* d = [t subscribeNext:^(id x) {
		didGetNext = [x isEqual:@1];
	} error:^(NSError *error) {
		didError = false;
	} completed:^{
		didComplete = true;
	}];
	
	expect(d).to.beNil;
	expect(didGetNext).to.beTruthy;
	expect(didError).to.beFalsy;
	expect(didComplete).to.beTruthy;
});

SpecEnd
