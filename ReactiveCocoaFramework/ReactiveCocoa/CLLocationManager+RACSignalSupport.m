//
//  CLLocationManager+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "CLLocationManager+RACSignalSupport.h"
#import "EXTScope.h"
#import "NSObject+RACDeallocating.h"
#import "NSObject+RACDescription.h"
#import "RACDelegateProxy.h"
#import "RACDisposable.h"
#import "RACSignal.h"
#import "RACSignal+Operations.h"
#import "RACSubscriber.h"
#import <libkern/OSAtomic.h>
#import <objc/runtime.h>

@implementation CLLocationManager (RACSignalSupport)

static void RACUseDelegateProxy(CLLocationManager *self) {
	if (self.delegate != self.rac_delegateProxy) {
		self.rac_delegateProxy.rac_proxiedDelegate = self.delegate;
	}

	// Apple classes are known to pre-cache protocol compliance at the time of
	// assigning a delegate. Every call to this method might be following the
	// addition of a method to the delegate proxy and resetting the delegate
	// property allows the receiver re-perform its caching.
	self.delegate = (id)self.rac_delegateProxy;
}

- (RACDelegateProxy *)rac_delegateProxy {
	RACDelegateProxy *proxy = objc_getAssociatedObject(self, _cmd);
	if (proxy != nil) return proxy;

	proxy = [[RACDelegateProxy alloc] initWithProtocol:@protocol(CLLocationManagerDelegate)];
	objc_setAssociatedObject(self, _cmd, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return proxy;
}

- (RACSignal *)rac_activeLocationUpdatesSignal {
	static volatile int32_t subscriberCount = 0;

	@weakify(self);
	return [[[RACSignal
		createSignal:^(id<RACSubscriber> subscriber) {
			@strongify(self);

			// Subscribe to location updates.

			// The preferred delegate method for OS X 10.9+ and iOS 6.0+.
			SEL preferredSelector = NSSelectorFromString(@"locationManager:didUpdateLocations:");
			struct objc_method_description preferredMethod = protocol_getMethodDescription(@protocol(CLLocationManagerDelegate), preferredSelector, NO, YES);

			if (preferredMethod.name != NULL) {
				[[[self.rac_delegateProxy
					signalForSelector:preferredSelector]
					reduceEach:^(CLLocationManager *manager, NSArray *locations) {
						return [locations lastObject];
					}]
					subscribe:subscriber];
			} else {
				// Fallback for OS X [10.7, 10.9) and iOS 5.
				[[[self.rac_delegateProxy
					signalForSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]
					reduceEach:^(CLLocationManager *manager, CLLocation* newLocation, CLLocation *oldLocation) {
						return newLocation;
					}]
					subscribe:subscriber];
			}

			// Subscribe to location errors.

			[[[[self.rac_delegateProxy
				signalForSelector:@selector(locationManager:didFailWithError:)]
				reduceEach:^(CLLocationManager *manager, NSError *error) {
					return [RACSignal error:error];
				}]
				flatten]
				subscribe:subscriber];

			// Flip the switches.

			RACUseDelegateProxy(self);

			if (OSAtomicIncrement32Barrier(&subscriberCount) == 1) {
				[self startUpdatingLocation];
			} else {
				// Replay most recent location to later subscribers.
				[subscriber sendNext:self.location];
			}

			return [RACDisposable disposableWithBlock:^{
				@strongify(self);
				if (OSAtomicDecrement32Barrier(&subscriberCount) == 0) [self stopUpdatingLocation];
			}];
		}]
		takeUntil:self.rac_willDeallocSignal]
		setNameWithFormat:@"%@ -rac_activeLocationUpdatesSignal", [self rac_description]];
}

@end
