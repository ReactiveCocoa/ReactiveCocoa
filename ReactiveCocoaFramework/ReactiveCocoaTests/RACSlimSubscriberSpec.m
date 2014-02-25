#import "RACSlimSubscriber.h"
#import "RACDisposable.h"
#import "RACSignal.h"

SpecBegin(RACSlimSubscriber)

it(@"should forward to the given next block", ^{
	__block NSUInteger callsToNext = 0;
	__block id lastNext = nil;
	RACSlimSubscriber *r = [RACSlimSubscriber
		slimSubscriberWithNext:^(id x) {
			callsToNext++;
			lastNext = x;
		}
		andError:nil
		andComplete:nil
		andDidSubscribeWith:nil];
	
	expect(callsToNext).to.equal(0);
	[r sendNext:@""];
	expect(callsToNext).to.equal(1);
	expect(lastNext).to.equal(@"");
});

it(@"should forward to the given blocks", ^{
	__block NSUInteger callsToError = 0;
	__block id lastError = nil;
	RACSlimSubscriber *r = [RACSlimSubscriber
		slimSubscriberWithNext:nil
		andError:^(NSError *error) {
			callsToError++;
			lastError = error;
		}
		andComplete:nil
		andDidSubscribeWith:nil];
	
	expect(callsToError).to.equal(0);
	NSError* e = [NSError errorWithDomain:@"" code:0 userInfo:@{}];
	[r sendError:e];
	expect(callsToError).to.equal(1);
	expect(lastError).to.equal(e);
});

it(@"should forward to the given blocks", ^{
	__block NSUInteger callsToCompleted = 0;
	RACSlimSubscriber *r = [RACSlimSubscriber
		slimSubscriberWithNext:nil
		andError:nil
		andComplete:^{
			callsToCompleted++;
		}
		andDidSubscribeWith:nil];
	
	expect(callsToCompleted).to.equal(0);
	[r sendCompleted];
	expect(callsToCompleted).to.equal(1);
});

it(@"should override next", ^{
	__block NSUInteger callsToNext = 0;
	__block id lastNext = nil;
	RACSlimSubscriber *r = [[RACSlimSubscriber
		slimSubscriberWithNext:nil
		andError:nil
		andComplete:nil
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
	__block NSUInteger callsToError = 0;
	__block id lastError = nil;
	RACSlimSubscriber *r = [[RACSlimSubscriber
		slimSubscriberWithNext:nil
		andError:nil
		andComplete:nil
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
	__block NSUInteger callsToCompleted = 0;
	RACSlimSubscriber *r = [[RACSlimSubscriber
		slimSubscriberWithNext:nil
		andError:nil
		andComplete:nil
		andDidSubscribeWith:nil]
		withSendComplete:^{
			callsToCompleted++;
		}];
	
	expect(callsToCompleted).to.equal(0);
	[r sendCompleted];
	expect(callsToCompleted).to.equal(1);
});

it(@"should return self when wrapped", ^{
	RACSlimSubscriber *r = [RACSlimSubscriber new];
	RACSlimSubscriber *w = [RACSlimSubscriber slimSubscriberWrapping:r];
	expect(r).to.equal(w);
});

it(@"should wrap arbitrary subjects", ^{
	RACSignal *t = [RACSignal createSignal:^(id<RACSubscriber> subscriber) {
		RACSlimSubscriber *s = [RACSlimSubscriber slimSubscriberWrapping:subscriber];
		[s sendNext:@1];
		[s sendCompleted];
		return (RACDisposable *)nil;
	}];
	
	__block BOOL didComplete = NO;
	__block BOOL didError = NO;
	__block BOOL didGetNext = NO;
	RACDisposable *d = [t subscribeNext:^(id x) {
		didGetNext = [x isEqual:@1];
	} error:^(NSError *error) {
		didError = YES;
	} completed:^{
		didComplete = YES;
	}];
	
	expect(d).to.beNil;
	expect(didGetNext).to.beTruthy;
	expect(didError).to.beFalsy;
	expect(didComplete).to.beTruthy;
});

SpecEnd
