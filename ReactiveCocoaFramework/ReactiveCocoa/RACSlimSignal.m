#import "RACSlimSignal.h"

@interface RACSlimSignal ()

@property (readonly,nonatomic,strong) RACDisposable *(^subscribe)(id<RACSubscriber> subscriber);

@end

@implementation RACSlimSignal

- (instancetype)initWithSubscribe:(RACDisposable *(^)(id<RACSubscriber> subscriber))subscribe {
	NSCParameterAssert(subscribe != nil);
	self = [super init];
	if (self == nil) return nil;
	
	_subscribe = subscribe;
	return self;
}

- (instancetype)init {
	// default to 'never' instead of 'fail horribly with segfault'
	return [self initWithSubscribe:^RACDisposable *(id<RACSubscriber> subscriber) { return nil; }];
}

+ (RACSlimSignal *)slimSignalWithSubscribe:(RACDisposable *(^)(id<RACSubscriber> subscriber))subscribe {
	NSCParameterAssert(subscribe != nil);
	return [[RACSlimSignal alloc] initWithSubscribe:subscribe];
}

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return _subscribe(subscriber);
}

@end
