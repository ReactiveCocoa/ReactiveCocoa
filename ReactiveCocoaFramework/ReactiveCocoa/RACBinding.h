//
//  RACBinding.h
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACSignal.h"
#import "RACSubscriber.h"

@class RACDisposable;

// A binding to a property.
//
// Refer to the documentation of subclasses and of methods returning a
// `RACBinding` for specifics.
//
// It is considered undefined behavior to send `error` to a RACBinding.
@interface RACBinding : RACSignal <RACSubscriber>

@end

@interface RACBinding (Deprecated)

- (RACDisposable *)bindTo:(RACBinding *)binding __attribute__((deprecated("Subscribe each binding to the other instead.")));

@end
