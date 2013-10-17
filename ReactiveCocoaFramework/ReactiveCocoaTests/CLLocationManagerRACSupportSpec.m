//
//  CLLocationManagerRACSupportSpec.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#if RAC_ENABLE_CORE_LOCATION_TESTS

#import "CLLocationManager+RACSignalSupport.h"
#import "RACSignal.h"

SpecBegin(CLLocationManagerRACSupport)

describe(@"-rac_activeLocationUpdatesSignal", ^{
	it(@"should eventually send location update", ^{
		expect([CLLocationManager authorizationStatus]).to.equal(kCLAuthorizationStatusAuthorized);

		CLLocationManager *manager = [[CLLocationManager alloc] init];
		expect(manager).notTo.beNil();

		__block CLLocation *lastLocation = nil;
		[[manager rac_activeLocationUpdatesSignal] subscribeNext:^(CLLocation* x) {
			lastLocation = x;
		}];

		NSTimeInterval originalTimeout = Expecta.asynchronousTestTimeout;
		Expecta.asynchronousTestTimeout = 5;
		expect(lastLocation).willNot.beNil();
		Expecta.asynchronousTestTimeout = originalTimeout;
	});
});

SpecEnd

#endif
