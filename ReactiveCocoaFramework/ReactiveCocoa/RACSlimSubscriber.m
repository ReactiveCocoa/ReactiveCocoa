#import "RACSlimSubscriber.h"

@interface RACSlimSubscriber ()

@property (readonly,nonatomic,strong) void (^sendNext)(id x);
@property (readonly,nonatomic,strong) void (^sendError)(NSError *error);
@property (readonly,nonatomic,strong) void (^sendComplete)(void);
@property (readonly,nonatomic,strong) void (^didSubscribeWithDisposable)(RACDisposable *disposable);

@end

@implementation RACSlimSubscriber

- (instancetype)initWithNext:(void (^)(id))onNext andError:(void (^)(NSError *error))onError andComplete:(void (^)(void))onCompleted andDidSubscribeWith:(void (^)(RACDisposable *disposable))didSubscribeWithDisposable {
	self = [super init];
	if (self == nil) return nil;

	_sendNext = onNext ?: ^(id _){};
	_sendError = onError ?: ^(NSError *_){};
	_sendComplete = onCompleted ?: ^{};
	_didSubscribeWithDisposable = didSubscribeWithDisposable ?: ^(RACDisposable *d){};
	return self;
}
- (instancetype) init {
	return [self
		initWithNext:nil
		andError:nil
		andComplete:nil
		andDidSubscribeWith:nil];
}
+ (RACSlimSubscriber *) slimSubscriberWithNext:(void (^)(id x))onNext andError:(void (^)(NSError *error))onError andComplete:(void (^)(void))onCompleted andDidSubscribeWith:(void (^)(RACDisposable *disposable))didSubscribeWithDisposable {
	return [[RACSlimSubscriber alloc]
		initWithNext:onNext
		andError:onError
		andComplete:onCompleted
		andDidSubscribeWith:didSubscribeWithDisposable];
}

+ (RACSlimSubscriber *)slimSubscriberWrapping:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);
	if ([subscriber isKindOfClass:RACSlimSubscriber.class]) {
		return subscriber;
	}
	
	return [RACSlimSubscriber
		slimSubscriberWithNext:^(id x) { [subscriber sendNext:x]; }
		andError:^(NSError *error) { [subscriber sendError:error]; }
		andComplete:^{ [subscriber sendCompleted]; }
		andDidSubscribeWith:^(RACDisposable *x) { [subscriber didSubscribeWithDisposable:x]; }];
}


- (void)sendNext:(id)value {
	_sendNext(value);
}
- (void)sendCompleted {
	_sendComplete();
}
- (void)sendError:(NSError *)error {
	_sendError(error);
}
- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	_didSubscribeWithDisposable(disposable);
}

- (RACSlimSubscriber *)withSendNext:(void (^)(id x))newSendNext {
	NSCParameterAssert(newSendNext != nil);
	return [RACSlimSubscriber
		slimSubscriberWithNext:newSendNext
		andError:_sendError
		andComplete:_sendComplete
		andDidSubscribeWith:_didSubscribeWithDisposable];
}

- (RACSlimSubscriber *)withSendError:(void (^)(NSError *error))newSendError {
	NSCParameterAssert(newSendError != nil);
	return [RACSlimSubscriber
		slimSubscriberWithNext:_sendNext
		andError:newSendError
		andComplete:_sendComplete
		andDidSubscribeWith:_didSubscribeWithDisposable];
}

- (RACSlimSubscriber *)withSendComplete:(void (^)(void))newSendComplete {
	NSCParameterAssert(newSendComplete != nil);
	return [RACSlimSubscriber
		slimSubscriberWithNext:_sendNext
		andError:_sendError
		andComplete:newSendComplete
		andDidSubscribeWith:_didSubscribeWithDisposable];
}

@end
