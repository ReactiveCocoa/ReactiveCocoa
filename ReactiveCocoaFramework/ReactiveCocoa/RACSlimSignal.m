#import "RACSlimSignal.h"

@implementation RACSlimSignal {
@private RACDisposable*(^_subscribe)(id<RACSubscriber> subscriber);
}

-(instancetype)initWithSubscribe:(RACDisposable*(^)(id<RACSubscriber> subscriber))subscribe {
    NSCParameterAssert(subscribe != nil);
	if (self = [super init]) {
		self->_subscribe = subscribe;
	}
	return self;
}

-(instancetype)init {
	// default to 'never' instead of 'fail horribly with segfault'
	return [self initWithSubscribe:^RACDisposable*(id<RACSubscriber> subscriber) { return nil; }];
}

+(RACSlimSignal*)slimSignalWithSubscribe:(RACDisposable*(^)(id<RACSubscriber> subscriber))subscribe {
    NSCParameterAssert(subscribe != nil);
    return [[RACSlimSignal alloc] initWithSubscribe:subscribe];
}

-(RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    return _subscribe(subscriber);
}

@end
