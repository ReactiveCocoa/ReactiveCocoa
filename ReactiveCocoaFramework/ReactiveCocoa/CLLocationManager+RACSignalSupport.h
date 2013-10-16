//
//  CLLocationManager+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

@class RACDelegateProxy;
@class RACSignal;

@interface CLLocationManager (RACSignalSupport)

/// A delegate proxy which will be set as the receiver's delegate when any of the
/// methods in this category are used.
@property (nonatomic, strong, readonly) RACDelegateProxy *rac_delegateProxy;

@end
