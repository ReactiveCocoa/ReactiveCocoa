//
//  RACPassthroughSubscriber.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-06-13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACPassthroughSubscriber.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSignalProvider.h"

static const char *cleanedDTraceString(NSString *original) {
	return [original stringByReplacingOccurrencesOfString:@"\\s+" withString:@" " options:NSRegularExpressionSearch range:NSMakeRange(0, original.length)].UTF8String;
}

static const char *cleanedSignalDescription(RACSignal *signal) {
	NSString *desc = signal.description;

	NSRange range = [desc rangeOfString:@" name:"];
	if (range.location != NSNotFound) {
		desc = [desc stringByReplacingCharactersInRange:range withString:@""];
	}

	return cleanedDTraceString(desc);
}

@interface RACPassthroughSubscriber ()

// The subscriber to which events should be forwarded.
@property (nonatomic, strong, readonly) id<RACSubscriber> innerSubscriber;

// The signal sending events to this subscriber.
//
// This property isn't `weak` because it's only used for DTrace probes, so
// a zeroing weak reference would incur an unnecessary performance penalty in
// normal usage.
@property (nonatomic, unsafe_unretained, readonly) RACSignal *signal;

// A disposable representing the subscription. When disposed, no further events
// should be sent to the `innerSubscriber`.
@property (nonatomic, strong, readonly) RACDisposable *disposable;

@end

@implementation RACPassthroughSubscriber

#pragma mark Lifecycle

- (instancetype)initWithSubscriber:(id<RACSubscriber>)subscriber signal:(RACSignal *)signal disposable:(RACDisposable *)disposable {
	NSCParameterAssert(subscriber != nil);

	self = [super init];
	if (self == nil) return nil;

	_innerSubscriber = subscriber;
	_signal = signal;
	_disposable = disposable;

	return self;
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	if (self.disposable.disposed) return;

	if (RACSIGNAL_NEXT_ENABLED()) {
		RACSIGNAL_NEXT(cleanedSignalDescription(self.signal), cleanedDTraceString(self.innerSubscriber.description), cleanedDTraceString([value description]));
	}

	[self.innerSubscriber sendNext:value];
}

- (void)sendError:(NSError *)error {
	if (self.disposable.disposed) return;

	if (RACSIGNAL_ERROR_ENABLED()) {
		RACSIGNAL_ERROR(cleanedSignalDescription(self.signal), cleanedDTraceString(self.innerSubscriber.description), cleanedDTraceString(error.description));
	}

	[self.innerSubscriber sendError:error];
}

- (void)sendCompleted {
	if (self.disposable.disposed) return;

	if (RACSIGNAL_COMPLETED_ENABLED()) {
		RACSIGNAL_COMPLETED(cleanedSignalDescription(self.signal), cleanedDTraceString(self.innerSubscriber.description));
	}

	[self.innerSubscriber sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	if (self.disposable.disposed) {
		[disposable dispose];
		return;
	}

	// We don't actually need to save this disposable, since the inner
	// subscriber will take care of it. We only care about cutting off the event
	// stream.
	[self.innerSubscriber didSubscribeWithDisposable:disposable];
}

@end
