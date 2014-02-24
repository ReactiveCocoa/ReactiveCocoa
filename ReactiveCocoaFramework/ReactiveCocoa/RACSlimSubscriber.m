#import "RACSlimSubscriber.h"

@implementation RACSlimSubscriber {
@private void(^_sendNext)(id x);
@private void(^_sendError)(NSError* error);
@private void(^_sendCompleted)(void);
@private void (^_didSubscribeWithDisposable)(RACDisposable* disposable);
}

-(instancetype)initWithNext:(void(^)(id))onNext
				   andError:(void(^)(NSError* error))onError
			   andCompleted:(void(^)(void))onCompleted
		andDidSubscribeWith:(void(^)(RACDisposable* disposable))didSubscribeWithDisposable {
    if (self = [super init]) {
        self->_sendNext = onNext ?: ^(id _){};
        self->_sendError = onError ?: ^(NSError* _){};
        self->_sendCompleted = onCompleted ?: ^{};
		self->_didSubscribeWithDisposable = didSubscribeWithDisposable ?: ^(RACDisposable* d){};
    }
    return self;
}
-(instancetype) init {
    return [self initWithNext:nil
					 andError:nil
				 andCompleted:nil
		  andDidSubscribeWith:nil];
}
+(RACSlimSubscriber*) slimSubscriberWithNext:(void(^)(id x))onNext
									andError:(void(^)(NSError* error))onError
								andCompleted:(void(^)(void))onCompleted
						 andDidSubscribeWith:(void(^)(RACDisposable* disposable))didSubscribeWithDisposable {
    return [[RACSlimSubscriber alloc] initWithNext:onNext
										  andError:onError
									  andCompleted:onCompleted
							   andDidSubscribeWith:didSubscribeWithDisposable];
}

+(RACSlimSubscriber*)slimSubscriberWrapping:(id<RACSubscriber>)subscriber {
    NSCParameterAssert(subscriber != nil);
	if ([subscriber isKindOfClass:RACSlimSubscriber.class]) {
		return subscriber;
	}
	
    return [RACSlimSubscriber slimSubscriberWithNext:^(id x) { [subscriber sendNext:x]; }
											andError:^(NSError* error) { [subscriber sendError:error]; }
										andCompleted:^{ [subscriber sendCompleted]; }
								 andDidSubscribeWith:^(RACDisposable* x) { [subscriber didSubscribeWithDisposable:x]; }];
}


-(void)sendNext:(id)value {
    _sendNext(value);
}
-(void)sendCompleted {
    _sendCompleted();
}
-(void)sendError:(NSError *)error {
    _sendError(error);
}
-(void)didSubscribeWithDisposable:(RACDisposable *)disposable {
    _didSubscribeWithDisposable(disposable);
}

-(RACSlimSubscriber*)withSendNext:(void(^)(id x))newSendNext {
    NSCParameterAssert(newSendNext != nil);
    return [RACSlimSubscriber slimSubscriberWithNext:newSendNext
											andError:_sendError
										andCompleted:_sendCompleted
								 andDidSubscribeWith:_didSubscribeWithDisposable];
}

-(RACSlimSubscriber*)withSendError:(void(^)(NSError* error))newSendError {
    NSCParameterAssert(newSendError != nil);
    return [RACSlimSubscriber slimSubscriberWithNext:_sendNext
											andError:newSendError
										andCompleted:_sendCompleted
								 andDidSubscribeWith:_didSubscribeWithDisposable];
}

-(RACSlimSubscriber*)withSendCompleted:(void(^)(void))newSendCompleted {
    NSCParameterAssert(newSendCompleted != nil);
    return [RACSlimSubscriber slimSubscriberWithNext:_sendNext
											andError:_sendError
										andCompleted:newSendCompleted
								 andDidSubscribeWith:_didSubscribeWithDisposable];
}

@end
