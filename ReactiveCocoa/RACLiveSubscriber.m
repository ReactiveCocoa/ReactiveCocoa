//
//  RACLiveSubscriber.m
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-11-04.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACLiveSubscriber.h"
#import "EXTScope.h"
#import "RACCompoundDisposable.h"
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

@interface RACLiveSubscriber ()

// These callbacks should only be accessed while synchronized on self.
@property (nonatomic, copy) void (^next)(id value);
@property (nonatomic, copy) void (^error)(NSError *error);
@property (nonatomic, copy) void (^completed)(void);

@end

@implementation RACLiveSubscriber

#pragma mark Properties

@synthesize disposable = _disposable;

#pragma mark Lifecycle

+ (instancetype)subscriberForwardingToSubscriber:(id<RACSubscriber>)subscriber {
	NSCParameterAssert(subscriber != nil);

	RACLiveSubscriber *liveSubscriber = [self subscriberWithNext:^(id x) {
		[subscriber sendNext:x];
	} error:^(NSError *error) {
		[subscriber sendError:error];
	} completed:^{
		[subscriber sendCompleted];
	}];

	[subscriber.disposable addDisposable:liveSubscriber.disposable];
	[liveSubscriber.disposable addDisposable:[RACDisposable disposableWithBlock:^{
		[subscriber.disposable removeDisposable:liveSubscriber.disposable];
	}]];

	return liveSubscriber;
}

+ (instancetype)subscriberWithNext:(void (^)(id x))next error:(void (^)(NSError *error))error completed:(void (^)(void))completed {
	RACLiveSubscriber *subscriber = [[self alloc] init];

	subscriber.next = next;
	subscriber.error = error;
	subscriber.completed = completed;

	return subscriber;
}

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	@weakify(self);

	RACDisposable *selfDisposable = [RACDisposable disposableWithBlock:^{
		@strongify(self);
		if (self == nil) return;

		@synchronized (self) {
			self.next = nil;
			self.error = nil;
			self.completed = nil;
		}
	}];

	_disposable = [RACCompoundDisposable compoundDisposableWithDisposables:@[ selfDisposable ]];
	
	return self;
}

- (void)dealloc {
	[self.disposable dispose];
}

#pragma mark RACSubscriber

- (void)sendNext:(id)value {
	@synchronized (self) {
		void (^nextBlock)(id) = [self.next copy];

		if (nextBlock == nil) return;
		if (RACSIGNAL_NEXT_ENABLED()) {
			RACSIGNAL_NEXT(cleanedSignalDescription(self.signal), cleanedDTraceString(self.description), cleanedDTraceString([value description]));
		}

		nextBlock(value);
	}
}

- (void)sendError:(NSError *)error {
	@synchronized (self) {
		void (^errorBlock)(NSError *) = [self.error copy];
		[self.disposable dispose];

		if (errorBlock == nil) return;
		if (RACSIGNAL_ERROR_ENABLED()) {
			RACSIGNAL_ERROR(cleanedSignalDescription(self.signal), cleanedDTraceString(self.description), cleanedDTraceString(error.description));
		}

		errorBlock(error);
	}
}

- (void)sendCompleted {
	@synchronized (self) {
		void (^completedBlock)(void) = [self.completed copy];
		[self.disposable dispose];

		if (completedBlock == nil) return;
		if (RACSIGNAL_COMPLETED_ENABLED()) {
			RACSIGNAL_COMPLETED(cleanedSignalDescription(self.signal), cleanedDTraceString(self.description));
		}

		completedBlock();
	}
}

@end
